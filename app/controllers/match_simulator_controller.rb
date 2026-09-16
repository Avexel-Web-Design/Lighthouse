class MatchSimulatorController < ApplicationController
  before_action :require_event!

  def new
    authorize :match_simulator, :new?

    @teams = FrcTeam.at_event(current_event).order(:team_number)
    @saved_simulations = policy_scope(SimulationResult).where(event: current_event).order(created_at: :desc).limit(10)
  end

  def create
    authorize :match_simulator, :create?

    red_team_ids = params[:red_team_ids]&.reject(&:blank?) || []
    blue_team_ids = params[:blue_team_ids]&.reject(&:blank?) || []

    @red_teams = FrcTeam.at_event(current_event).where(id: red_team_ids)
    @blue_teams = FrcTeam.at_event(current_event).where(id: blue_team_ids)

    # Use Monte Carlo simulation instead of simple sum
    iterations = (params[:iterations] || 1000).to_i.clamp(100, 5000)
    simulator = MatchSimulatorService.new(current_event, statbotics: StatboticsClient.new)
    @simulation = simulator.simulate(@red_teams.to_a, @blue_teams.to_a)

    @red_score = @simulation[:red_avg]
    @blue_score = @simulation[:blue_avg]
    @red_win_pct = @simulation[:red_win_pct]
    @blue_win_pct = @simulation[:blue_win_pct]
    @margin = @simulation[:margin_of_victory]
    @red_team_stats = @simulation[:red_team_stats]
    @blue_team_stats = @simulation[:blue_team_stats]

    # Save simulation if requested
    if params[:save_simulation] == "1"
      simulation_record = SimulationResult.new(
        user: current_user,
        event: current_event,
        name: params[:simulation_name].presence || "Simulation #{Time.current.strftime('%H:%M')}",
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
end
