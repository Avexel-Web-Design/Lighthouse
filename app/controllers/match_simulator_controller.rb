class MatchSimulatorController < ApplicationController
  MAX_TEAMS_PER_ALLIANCE = 3
  MIN_ITERATIONS = 100
  MAX_ITERATIONS = 5000
  MAX_SIMULATION_NAME_LENGTH = 80

  before_action :require_event!

  def new
    authorize :match_simulator, :new?

    @teams = FrcTeam.at_event(current_event).order(:team_number)
    @saved_simulations = policy_scope(SimulationResult).where(event: current_event).order(created_at: :desc).limit(10)
  end

  def create
    authorize :match_simulator, :create?

    simulator_params = params.permit(:iterations, :save_simulation, :simulation_name, red_team_ids: [], blue_team_ids: [])
    red_team_ids = sanitize_team_ids(simulator_params[:red_team_ids])
    blue_team_ids = sanitize_team_ids(simulator_params[:blue_team_ids])

    @red_teams = FrcTeam.at_event(current_event).where(id: red_team_ids)
    @blue_teams = FrcTeam.at_event(current_event).where(id: blue_team_ids)

    # Use Monte Carlo simulation instead of simple sum
    iterations = simulator_params[:iterations].to_i
    iterations = 1000 if iterations.zero?
    iterations = iterations.clamp(MIN_ITERATIONS, MAX_ITERATIONS)
    simulator = MatchSimulatorService.new(current_event, statbotics: StatboticsClient.new)
    @simulation = simulator.simulate(@red_teams.to_a, @blue_teams.to_a, iterations: iterations)

    @red_score = @simulation[:red_avg]
    @blue_score = @simulation[:blue_avg]
    @red_win_pct = @simulation[:red_win_pct]
    @blue_win_pct = @simulation[:blue_win_pct]
    @margin = @simulation[:margin_of_victory]
    @red_team_stats = @simulation[:red_team_stats]
    @blue_team_stats = @simulation[:blue_team_stats]

    # Save simulation if requested
    if simulator_params[:save_simulation] == "1"
      simulation_record = SimulationResult.new(
        user: current_user,
        event: current_event,
        name: simulation_name_from(simulator_params[:simulation_name]),
        red_team_ids: red_team_ids.map(&:to_i),
        blue_team_ids: blue_team_ids.map(&:to_i),
        results: @simulation,
        iterations: iterations
      )
      authorize simulation_record
      simulation_record.save!
    end

    @teams = FrcTeam.at_event(current_event).order(:team_number)

    respond_to do |format|
      format.html { render :new }
      format.turbo_stream
    end
  end

  private

  def sanitize_team_ids(raw_ids)
    Array(raw_ids).reject(&:blank?).map(&:to_i).select(&:positive?).uniq.first(MAX_TEAMS_PER_ALLIANCE)
  end

  def simulation_name_from(raw_name)
    name = raw_name.to_s.strip.first(MAX_SIMULATION_NAME_LENGTH)
    name.presence || "Simulation #{Time.current.strftime('%H:%M')}"
  end
end
