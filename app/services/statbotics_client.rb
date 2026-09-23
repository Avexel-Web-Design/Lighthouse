# frozen_string_literal: true

class StatboticsClient < BaseApiClient
  BASE_URL = "https://api.statbotics.io/v3"
  CACHE_TTL = 1.hour
  LOG_PREFIX = "StatboticsClient"

  def initialize
    @conn = self.class.build_connection(
      base_url: BASE_URL,
      headers: { "Accept" => "application/json" }
    )
  end

  # GET /team_year/{team}/{year}
  # Returns EPA data for a team in a given year.
  def team_year(team_number, year)
    cached_get("statbotics:team_year:#{team_number}:#{year}", "team_year/#{team_number}/#{year}")
  end

  # GET /team_events?event={event_key}
  # Returns EPA + record for ALL teams at an event in a single request.
  def team_events(event_key)
    cached_get("statbotics:team_events:#{event_key}", "team_events", event: event_key)
  end

  # GET /event/{event_key}
  # Returns event-level EPA and prediction data.
  def event(event_key)
    cached_get("statbotics:event:#{event_key}", "event/#{event_key}")
  end

  # GET /matches?event={event_key}
  # Returns match predictions and results for an event.
  def matches(event_key)
    cached_get("statbotics:matches:#{event_key}", "matches", event: event_key)
  end

  private

  def cached_get(cache_key, path, params = {})
    super(cache_key, path, params, expires_in: CACHE_TTL, log_prefix: LOG_PREFIX)
  end
end
