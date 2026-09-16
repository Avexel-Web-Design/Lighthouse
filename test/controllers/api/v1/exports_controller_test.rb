require "test_helper"

class Api::V1::ExportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    @scout = users(:scout_user)
    @event = events(:championship)
  end

  test "admin token can export event data" do
    get "/api/v1/exports/scouting_data", params: { event_id: @event.id },
      headers: { "Authorization" => "Bearer #{@admin.api_token}" }, as: :json

    assert_response :success
  end

  test "scout token is denied export" do
    get "/api/v1/exports/scouting_data", params: { event_id: @event.id },
      headers: { "Authorization" => "Bearer #{@scout.api_token}" }, as: :json

    assert_response :forbidden
  end

  test "export with invalid event returns not found" do
    get "/api/v1/exports/scouting_data", params: { event_id: 0 },
      headers: { "Authorization" => "Bearer #{@admin.api_token}" }, as: :json

    assert_response :not_found
  end

  test "API rejects cross-event match scope" do
    other_event = Event.create!(name: "Other Event", tba_key: "2026other#{SecureRandom.hex(4)}", year: 2026)

    post "/api/v1/scouting_entries", params: {
      scouting_entry: {
        match_id: matches(:qm1).id,
        frc_team_id: frc_teams(:team_254).id,
        event_id: other_event.id,
        client_uuid: "x-event-#{SecureRandom.hex(8)}",
        data: {}
      }
    }, headers: { "Authorization" => "Bearer #{@admin.api_token}" }, as: :json

    assert_response :unprocessable_entity
  end
end
