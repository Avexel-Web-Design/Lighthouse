class TeamComparisonsController < ApplicationController
  before_action :require_event!
  skip_after_action :pundit_verify

  RADAR_METRICS = %w[avg_total_points avg_auton_points fuel_accuracy_pct avg_climb_points avg_defense_rating].freeze
  TEAM_COLORS = %w[#f97316 #3b82f6 #f59e0b #ef4444 #8b5cf6 #ec4899].freeze

  # Per-entry stats available for the line chart
  LINE_CHART_STATS = {
    "total_points" => { label: "Total Points", method: :total_points },
    "auton_points" => { label: "Auton Points", method: :auton_points },
    "accuracy" => { label: "Accuracy %", method: :fuel_accuracy },
    "climb_points" => { label: "Climb Points", method: :climb_points },
    "defense_rating" => { label: "Defence Rating", method: :defense_rating },
    "fuel_made" => { label: "Fuel Made", method: :total_fuel_made },
    "fuel_missed" => { label: "Fuel Missed", method: :total_fuel_missed }
  }.freeze

  def show
    authorize :team_comparison, :show?

    # Support both comma-separated ?teams=1,2,3 and checkbox array ?team_ids[]=1&team_ids[]=2
    team_ids = if params[:team_ids].present?
      Array(params[:team_ids]).map(&:to_i).reject(&:zero?)
    else
      (params[:teams] || "").split(",").map(&:to_i).reject(&:zero?)
    end
    team_ids = team_ids.first(6) # Limit to 6 teams
    @teams = FrcTeam.where(id: team_ids).order(:team_number)
    @all_teams = FrcTeam.at_event(current_event).order(:team_number)

    @summaries = {}
    @entries_by_team = {}
    @pit_data = {}

    @teams.each do |team|
      @summaries[team.id] = TeamEventSummary.find_by(event: current_event, frc_team: team)
      @entries_by_team[team.id] = ScoutingEntry.where(event: current_event, frc_team: team)
                                               .includes(:match)
                                               .order(created_at: :asc)
      # Deterministic primary: latest non-rejected report.
      pit_entries = PitScoutingEntry.where(event: current_event, frc_team: team)
                                    .order(updated_at: :desc)
      @pit_data[team.id] = pit_entries.reject(&:rejected?).first || pit_entries.first
    end

    # Build radar chart data: event-wide values for percentile computation + per-team values
    all_summaries = TeamEventSummary.where(event: current_event)

    @radar_all_values = RADAR_METRICS.index_with do |metric|
      all_summaries.pluck(metric).compact.map(&:to_f)
    end

    @radar_teams = @teams.each_with_index.map do |team, i|
      summary = @summaries[team.id]
      values = RADAR_METRICS.index_with do |metric|
        val = summary&.public_send(metric)
        val.nil? ? nil : val.to_f
      end
      { name: "##{team.team_number}", color: TEAM_COLORS[i % TEAM_COLORS.size], values: values }
    end

    # Build line chart data for all stats (switched client-side)
    @line_chart_stats = LINE_CHART_STATS.transform_values { |v| v[:label] }
    @line_chart_data = LINE_CHART_STATS.each_with_object({}) do |(key, config), result|
      result[key] = @teams.map do |team|
        entries = @entries_by_team[team.id] || []
        {
          name: "##{team.team_number}",
          data: entries.each_with_object({}) do |entry, hash|
            label = entry.match&.display_name || "Entry #{entry.id}"
            hash[label] = entry.public_send(config[:method])
          end
        }
      end
    end
  end
end
