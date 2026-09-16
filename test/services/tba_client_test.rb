# frozen_string_literal: true

require "test_helper"

class TbaClientTest < ActiveSupport::TestCase
  FakeResponse = Struct.new(:status, :body) do
    def success?
      status >= 200 && status < 300
    end
  end

  class FakeConnection
    attr_reader :requested_urls

    def initialize(response: nil, error: nil)
      @response = response
      @error = error
      @requested_urls = []
    end

    def get(url)
      @requested_urls << url
      raise @error if @error

      @response
    end
  end

  setup do
    @original_key = ENV["TBA_API_KEY"]
    ENV["TBA_API_KEY"] = "test-key"
    @client = TbaClient.new(api_key: "test-key")
  end

  teardown do
    if @original_key.nil?
      ENV.delete("TBA_API_KEY")
    else
      ENV["TBA_API_KEY"] = @original_key
    end
  end

  test "configured? is true when an API key is present" do
    assert TbaClient.configured?
  end

  test "configured? is false when the API key is missing" do
    ENV.delete("TBA_API_KEY")

    assert_not TbaClient.configured?
  end

  test "returns nil without hitting the network when unconfigured" do
    ENV.delete("TBA_API_KEY")
    client = TbaClient.new(api_key: nil)

    assert_nil client.event("2026cmp")
    assert_nil client.event_matches("2026cmp")
  end

  test "event returns the response body on success" do
    stub_connection(FakeResponse.new(200, { "name" => "Championship", "key" => "2026cmp" }))

    assert_equal({ "name" => "Championship", "key" => "2026cmp" }, @client.event("2026cmp"))
  end

  test "event_teams returns the teams array on success" do
    stub_connection(FakeResponse.new(200, [ { "key" => "frc254" } ]))

    assert_equal [ { "key" => "frc254" } ], @client.event_teams("2026cmp")
  end

  test "event_matches requests the matches endpoint" do
    conn = stub_connection(FakeResponse.new(200, []))

    @client.event_matches("2026cmp")

    assert conn.requested_urls.any? { |url| url.include?("/event/2026cmp/matches") }
  end

  test "team and event_rankings request their endpoints" do
    conn = stub_connection(FakeResponse.new(200, {}))

    @client.team("frc254")
    @client.event_rankings("2026cmp")

    assert conn.requested_urls.any? { |url| url.include?("/team/frc254") }
    assert conn.requested_urls.any? { |url| url.include?("/event/2026cmp/rankings") }
  end

  test "returns nil on non-success responses" do
    stub_connection(FakeResponse.new(404, { "Error" => "Not found" }))

    assert_nil @client.event("2026bogus")
  end

  test "returns nil when Faraday raises" do
    stub_connection(error: Faraday::ConnectionFailed.new("connection refused"))

    assert_nil @client.event("2026cmp")
  end

  private

  def stub_connection(response = nil, error: nil)
    conn = FakeConnection.new(response: response, error: error)
    @client.instance_variable_set(:@conn, conn)
    conn
  end
end
