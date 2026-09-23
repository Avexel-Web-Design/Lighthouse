require "test_helper"

class RequestHardeningTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin_user)
    @event = events(:championship)
    @team = frc_teams(:team_4414)
    sign_in_as(@user)
    select_event(@event)
  end

  test "authorization headers do not bypass session sync origin checks" do
    [ sync_scouting_entries_path, sync_pit_scouting_entries_path, import_qr_imports_path ].each do |path|
      post path, params: { entries: [], entry: { notes: "test" } },
        headers: { "Authorization" => "Bearer #{@user.api_token}", "Origin" => "https://evil.example" }, as: :json
      assert_response :forbidden
    end
  end

  test "scouting form preserves dynamic JSON and structured autonomous data" do
    data = scouting_data
    post scouting_entries_path, params: {
      scouting_entry: { frc_team_id: @team.id, data: { _json: data.to_json } }
    }
    assert_response :redirect
    assert_equal data, @user.scouting_entries.order(:id).last.data
  end

  test "offline sync accepts an older event while a different event is selected" do
    older_event = Event.create!(name: "Older Event", tba_key: "2025older", year: 2025)
    [ [ sync_scouting_entries_path, ScoutingEntry ], [ sync_pit_scouting_entries_path, PitScoutingEntry ] ].each do |path, model|
      uuid = SecureRandom.uuid
      post path, params: { entries: [ { client_uuid: uuid, event_id: older_event.id, frc_team_id: @team.id, data: scouting_data } ] },
        headers: { "Origin" => "http://www.example.com" }, as: :json
      assert_response :success
      assert_equal "created", response.parsed_body["results"].first["status"]
      assert_equal older_event.id, model.find_by!(client_uuid: uuid).event_id
      assert_equal scouting_data, model.find_by!(client_uuid: uuid).data
    end
  end

  test "bulk sync rejects malformed entry payloads without failing the batch" do
    post sync_scouting_entries_path,
      params: { entries: [ "not-an-object", { client_uuid: SecureRandom.uuid, event_id: @event.id, frc_team_id: @team.id, data: {} } ] },
      headers: { "Origin" => "http://www.example.com" }, as: :json

    assert_response :success
    results = response.parsed_body["results"]
    assert_equal "error", results.first["status"]
    assert_equal "created", results.second["status"]
  end

  test "sync rejects array-shaped scouting data" do
    post sync_scouting_entries_path,
      params: { entries: [ { client_uuid: SecureRandom.uuid, event_id: @event.id, frc_team_id: @team.id, data: [ "bad" ] } ] },
      headers: { "Origin" => "http://www.example.com" }, as: :json

    assert_response :success
    assert_equal "error", response.parsed_body["results"].first["status"]
  end

  private

  def scouting_data
    {
      "auton_fuel_made" => 3,
      "custom_metric" => { "successful" => true, "samples" => [ 1, 2 ] },
      "auton_path" => Array.new(60) { |i| { "x" => i / 100.0, "y" => 0.5 } },
      "auton_actions" => [ { "type" => "shoot", "position" => { "x" => 0.4, "y" => 0.6 } } ]
    }
  end
end
