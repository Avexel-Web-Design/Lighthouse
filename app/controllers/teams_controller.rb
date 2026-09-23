class TeamsController < ApplicationController
  TeamStatsSummary = Struct.new(
    :avg_total_points,
    :fuel_accuracy_pct,
    :avg_climb_points,
    :matches_scouted,
    :avg_defense_rating,
    :avg_fuel_made,
    :avg_fuel_missed,
    :stddev_total_points,
    keyword_init: true
  )

  before_action :require_event!

  def index
    @teams = policy_scope(FrcTeam)
               .at_event(current_event)
               .order(:team_number)

    @summaries = TeamEventSummary.where(event: current_event).index_by(&:frc_team_id)

    # Load Statbotics EPA — try bulk sync if cache is empty
    ensure_statbotics_cached!
    @statbotics_epa = StatboticsCache.where(event: current_event)
                                     .index_by(&:frc_team_id)

    # Fetch event rankings from TBA (cached 5 min)
    @rankings = fetch_tba_rankings
  end

  def show
    @team = policy_scope(FrcTeam).at_event(current_event).find(params[:id])
    authorize @team, policy_class: FrcTeamPolicy

    @entries = ScoutingEntry.where(event: current_event, frc_team: @team)
                            .includes(:match, :user)
                            .order(created_at: :desc)

    @summary = build_team_summary(@entries)
    @matches = @team.matches.where(event: current_event).ordered
    # Deterministic primary: latest non-rejected report. Rejected entries are
    # excluded so one bad entry can't shadow good data or cause phantom disagreements.
    ordered_pit_entries = PitScoutingEntry.where(event: current_event, frc_team: @team)
                                            .includes(:user)
                                            .order(updated_at: :desc)
    @pit_entries = ordered_pit_entries.reject(&:rejected?)
    @pit_entries = [ ordered_pit_entries.first ].compact if @pit_entries.empty?
    @pit_entry = @pit_entries.first
    @pit_discrepancies = PitScoutingDiscrepancyService.new(@pit_entries).discrepancies

    # Single DB query — no external API call
    @epa = StatboticsCache.find_by(event: current_event, frc_team: @team)
  end

  private

  def build_team_summary(entries)
    stats_entries = entries.select(&:counted?)
    return if stats_entries.empty?

    fuel_made_values = stats_entries.map(&:total_fuel_made)
    fuel_missed_values = stats_entries.map(&:total_fuel_missed)
    total_points_values = stats_entries.map(&:total_points)
    climb_points_values = stats_entries.map(&:climb_points)
    defense_values = stats_entries.map(&:defense_rating).select(&:positive?)

    total_fuel_attempts = fuel_made_values.sum + fuel_missed_values.sum

    TeamStatsSummary.new(
      avg_total_points: mean(total_points_values),
      fuel_accuracy_pct: total_fuel_attempts.positive? ? ((fuel_made_values.sum.to_f / total_fuel_attempts) * 100).round(1) : 0.0,
      avg_climb_points: mean(climb_points_values),
      matches_scouted: stats_entries.filter_map(&:match_id).uniq.count,
      avg_defense_rating: defense_values.any? ? mean(defense_values) : nil,
      avg_fuel_made: mean(fuel_made_values),
      avg_fuel_missed: mean(fuel_missed_values),
      stddev_total_points: sample_stddev(total_points_values)
    )
  end

  def mean(values)
    return 0.0 if values.empty?

    (values.sum.to_f / values.size).round(2)
  end

  def sample_stddev(values)
    return 0.0 if values.size < 2

    average = values.sum.to_f / values.size
    variance = values.sum { |value| (value - average)**2 } / (values.size - 1)
    Math.sqrt(variance).round(2)
  end

  def ensure_statbotics_cached!
    return if StatboticsCache.where(event: current_event).exists?
    return unless current_event.tba_key.present?

    SyncStatboticsJob.perform_now(current_event.id)
  rescue StandardError => e
    Rails.logger.warn("[TeamsController] Statbotics sync failed: #{e.message}")
  end

  # Returns a hash of team_number => rank from TBA, or empty hash on failure.
  def fetch_tba_rankings
    return {} unless current_event.tba_key.present?

    data = TbaClient.new.event_rankings(current_event.tba_key)
    return {} unless data.is_a?(Hash) && data["rankings"].is_a?(Array)

    data["rankings"].each_with_object({}) do |entry, hash|
      # TBA team_key is "frc254", extract the number
      team_number = entry["team_key"].to_s.delete_prefix("frc").to_i
      rp_avg = entry.dig("sort_orders", 0)&.to_f
      hash[team_number] = { rank: entry["rank"], rp_avg: rp_avg }
    end
  rescue StandardError => e
    Rails.logger.warn("[TeamsController] TBA rankings fetch failed: #{e.message}")
    {}
  end
end
