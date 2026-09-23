# frozen_string_literal: true

require "test_helper"

class StatboticsClientTest < ActiveSupport::TestCase
  setup do
    @client = StatboticsClient.new
  end

  test "shared client preserves API prefixes query parameters and cache keys" do
    original_cache = Rails.cache
    original_key = ENV["TBA_API_KEY"]
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    ENV["TBA_API_KEY"] = "test-key"
    tba = TbaClient.new
    cases = [
      [ tba, :event, [ "2026cmp" ], "/api/v3/event/2026cmp", "tba:event:2026cmp" ],
      [ tba, :event_teams, [ "2026cmp" ], "/api/v3/event/2026cmp/teams", "tba:event_teams:2026cmp" ],
      [ tba, :event_matches, [ "2026cmp" ], "/api/v3/event/2026cmp/matches", "tba:event_matches:2026cmp" ],
      [ tba, :event_rankings, [ "2026cmp" ], "/api/v3/event/2026cmp/rankings", "tba:event_rankings:2026cmp" ],
      [ tba, :team, [ "frc254" ], "/api/v3/team/frc254", "tba:team:frc254" ],
      [ @client, :team_year, [ 254, 2026 ], "/v3/team_year/254/2026", "statbotics:team_year:254:2026" ],
      [ @client, :team_events, [ "2026cmp" ], "/v3/team_events?event=2026cmp", "statbotics:team_events:2026cmp" ],
      [ @client, :event, [ "2026cmp" ], "/v3/event/2026cmp", "statbotics:event:2026cmp" ],
      [ @client, :matches, [ "2026cmp" ], "/v3/matches?event=2026cmp", "statbotics:matches:2026cmp" ]
    ]

    cases.group_by(&:first).each do |client, requests|
      stubs = Faraday::Adapter::Test::Stubs.new
      calls = 0
      requests.each do |_, method, _, path, _|
        stubs.get(path) do |env|
          calls += 1
          assert_equal URI(client.class::BASE_URL).host, env.url.host
          assert_equal "application/json", env.request_headers["Accept"]
          assert_equal "test-key", env.request_headers["X-TBA-Auth-Key"] if client == tba
          [ 200, { "Content-Type" => "application/json" }, { "endpoint" => method.to_s }.to_json ]
        end
      end
      client.instance_variable_get(:@conn).builder.adapter :test, stubs

      requests.each do |_, method, args, _, cache_key|
        expected = { "endpoint" => method.to_s }
        assert_equal expected, client.public_send(method, *args)
        assert_equal expected, Rails.cache.read(cache_key)
        assert_equal expected, client.public_send(method, *args)
      end
      assert_equal requests.size, calls
      stubs.verify_stubbed_calls
    end
  ensure
    Rails.cache = original_cache
    ENV["TBA_API_KEY"] = original_key
  end

  test "initializes without error" do
    assert_instance_of StatboticsClient, @client
  end

  test "BASE_URL points to statbotics API v3" do
    assert_equal "https://api.statbotics.io/v3", StatboticsClient::BASE_URL
  end

  test "CACHE_TTL is 1 hour" do
    assert_equal 1.hour, StatboticsClient::CACHE_TTL
  end

  test "team_year returns nil or a hash" do
    result = @client.team_year(254, 2026)
    assert(result.nil? || result.is_a?(Hash), "Expected nil or Hash, got #{result.class}")
  end

  test "event returns nil or a hash" do
    result = @client.event("2026cmp")
    assert(result.nil? || result.is_a?(Hash), "Expected nil or Hash, got #{result.class}")
  end

  test "matches returns nil or an array" do
    result = @client.matches("2026cmp")
    assert(result.nil? || result.is_a?(Array), "Expected nil or Array, got #{result.class}")
  end

  test "methods do not raise exceptions on failure" do
    assert_nothing_raised { @client.team_year(99999, 1900) }
    assert_nothing_raised { @client.event("nonexistent_key") }
    assert_nothing_raised { @client.matches("nonexistent_key") }
  end
end
