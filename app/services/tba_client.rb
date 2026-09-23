# frozen_string_literal: true

class TbaClient < BaseApiClient
  BASE_URL = "https://www.thebluealliance.com/api/v3"
  CACHE_TTL = 5.minutes
  LOG_PREFIX = "TbaClient"

  def self.configured?
    ENV["TBA_API_KEY"].present?
  end

  def initialize(api_key: ENV["TBA_API_KEY"])
    @api_key = api_key
    @conn = self.class.build_connection(
      base_url: BASE_URL,
      headers: { "X-TBA-Auth-Key" => @api_key, "Accept" => "application/json" }
    )
  end

  # GET /event/{event_key}
  def event(event_key)
    cached_get("tba:event:#{event_key}", "/event/#{event_key}")
  end

  # GET /event/{event_key}/teams
  def event_teams(event_key)
    cached_get("tba:event_teams:#{event_key}", "/event/#{event_key}/teams")
  end

  # GET /event/{event_key}/matches
  def event_matches(event_key)
    cached_get("tba:event_matches:#{event_key}", "/event/#{event_key}/matches")
  end

  # GET /team/{team_key}
  def team(team_key)
    cached_get("tba:team:#{team_key}", "/team/#{team_key}")
  end

  # GET /event/{event_key}/rankings
  def event_rankings(event_key)
    cached_get("tba:event_rankings:#{event_key}", "/event/#{event_key}/rankings")
  end

  private

  def cached_get(cache_key, path, params = {})
    unless self.class.configured?
      Rails.logger.warn("[#{LOG_PREFIX}] Missing TBA_API_KEY; skipping #{path}")
      return nil
    end

    super(cache_key, path, params, expires_in: CACHE_TTL, log_prefix: LOG_PREFIX)
  end
end
