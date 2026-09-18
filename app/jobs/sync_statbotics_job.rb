# frozen_string_literal: true

class SyncStatboticsJob < ApplicationJob
  queue_as :default
  retry_on Faraday::Error, wait: :polynomially_longer, attempts: 3

  # Fetches latest EPA and prediction data from Statbotics for an event.
  # Persists team EPA data to the statbotics_caches table for instant reads,
  # and warms the Rails cache for match predictions.
  def perform(event_id)
    event = Event.find_by(id: event_id)
    return unless event&.tba_key.present?

    client = StatboticsClient.new

    # Warm event-level and match prediction caches
    client.event(event.tba_key)
    client.matches(event.tba_key)

    # Bulk-fetch all team EPA data in a single API call and persist to DB
    sync_team_epa!(event, client)

    Rails.logger.info("[SyncStatboticsJob] Synced Statbotics data for event #{event.tba_key}")
  end

  private

  def sync_team_epa!(event, client)
    team_events_data = client.team_events(event.tba_key)
    return unless team_events_data.is_a?(Array)

    # Build a lookup of team_number -> frc_team for this event
    teams_by_number = event.frc_teams.index_by(&:team_number)
    now = Time.current

    team_events_data.each do |entry|
      team = teams_by_number[entry["team"]]
      next unless team

      epa = entry.dig("epa", "total_points") || {}
      record = entry.dig("record", "total") || {}
      qual = entry.dig("record", "qual") || {}

      cache = StatboticsCache.find_or_initialize_by(event: event, frc_team: team)
      cache.assign_attributes(
        epa_mean: epa["mean"].to_f,
        epa_sd: epa["sd"].to_f,
        wins: record["wins"].to_i,
        losses: record["losses"].to_i,
        ties: record["ties"].to_i,
        qual_wins: qual["wins"].to_i,
        qual_losses: qual["losses"].to_i,
        qual_rank: qual["rank"],
        qual_num_teams: qual["num_teams"],
        winrate: record["winrate"].to_f,
        data: entry,
        last_synced_at: now
      )
      # Per-team transaction so one bad row rolls back alone without
      # aborting the whole batch. Rescue stays narrow (validation only);
      # unexpected errors still bubble to retry.
      begin
        ActiveRecord::Base.transaction { cache.save! }
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.warn("[SyncStatboticsJob] Failed to cache team #{entry['team']}: #{e.message}")
      end
    end
  end
end
