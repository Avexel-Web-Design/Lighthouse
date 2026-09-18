require "test_helper"

class QrImportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    @analyst = users(:lead_user)
    @scout = users(:scout_user)
    @event = events(:championship)
    @team = frc_teams(:team_4414)
    @match = matches(:qm1)
  end

  # --- Scanner page access ---

  test "admin can access scanner page" do
    sign_in_as(@admin)
    select_event(@event)

    get scanner_qr_imports_path
    assert_response :success
  end

  test "analyst can access scanner page" do
    sign_in_as(@analyst)
    select_event(@event)

    get scanner_qr_imports_path
    assert_response :success
  end

  test "scout cannot access scanner page" do
    sign_in_as(@scout)
    select_event(@event)

    get scanner_qr_imports_path
    assert_response :redirect
    assert_equal "You are not authorized to perform this action.", flash[:alert]
  end

  test "unauthenticated user is redirected from scanner" do
    get scanner_qr_imports_path
    assert_redirected_to new_user_session_path
  end

  # --- Import: creating new entries ---

  test "import creates new entry with valid data" do
    sign_in_as(@admin)

    uuid = "qr-import-test-#{SecureRandom.hex(8)}"

    assert_difference("ScoutingEntry.count", 1) do
      post import_qr_imports_path,
        params: {
          entry: {
            client_uuid: uuid,
            match_key: @match.tba_key,
            team_number: @team.team_number,
            event_key: @event.tba_key,
            notes: "Imported via QR",
            status: 0,
            updated_at: Time.current.iso8601,
            data: { auton_fuel_made: 5, teleop_fuel_made: 10, endgame_climb: "L2" }
          }
        },
        headers: { "Origin" => "http://www.example.com" },
        as: :json
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "created", body["status"]
    assert_equal 4414, body["team_number"]

    entry = ScoutingEntry.find_by(client_uuid: uuid)
    assert_equal @admin, entry.user
    assert_equal 5, entry.data["auton_fuel_made"]
    assert_equal "L2", entry.data["endgame_climb"]
  end

  test "import returns existing when duplicate client_uuid and server is newer" do
    sign_in_as(@admin)

    existing = scouting_entries(:entry_qm1_254)
    old_time = (existing.updated_at - 1.hour).iso8601

    assert_no_difference("ScoutingEntry.count") do
      post import_qr_imports_path,
        params: {
          entry: {
            client_uuid: existing.client_uuid,
            match_key: existing.match.tba_key,
            team_number: existing.frc_team.team_number,
            event_key: existing.event.tba_key,
            notes: "Should not overwrite",
            status: 0,
            updated_at: old_time,
            data: { auton_fuel_made: 99 }
          }
        },
        headers: { "Origin" => "http://www.example.com" },
        as: :json
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "existing", body["status"]

    # Verify the server entry was NOT modified
    existing.reload
    assert_not_equal 99, existing.data["auton_fuel_made"]
  end

  test "import updates existing entry when incoming timestamp is newer" do
    sign_in_as(@admin)

    existing = scouting_entries(:entry_qm1_254)
    future_time = (existing.updated_at + 1.hour).iso8601

    assert_no_difference("ScoutingEntry.count") do
      post import_qr_imports_path,
        params: {
          entry: {
            client_uuid: existing.client_uuid,
            match_key: existing.match.tba_key,
            team_number: existing.frc_team.team_number,
            event_key: existing.event.tba_key,
            notes: "Updated via QR LWW",
            status: 0,
            updated_at: future_time,
            data: { auton_fuel_made: 99, teleop_fuel_made: 50 }
          }
        },
        headers: { "Origin" => "http://www.example.com" },
        as: :json
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "updated", body["status"]

    existing.reload
    assert_equal 99, existing.data["auton_fuel_made"]
    assert_equal 50, existing.data["teleop_fuel_made"]
    assert_equal "Updated via QR LWW", existing.notes
  end

  # --- Import: authorization ---

  test "scout cannot import via QR" do
    sign_in_as(@scout)

    assert_no_difference("ScoutingEntry.count") do
      post import_qr_imports_path,
        params: {
          entry: {
            client_uuid: "scout-attempt-#{SecureRandom.hex(4)}",
            team_number: @team.team_number,
            event_key: @event.tba_key,
            data: {}
          }
        },
        headers: { "Origin" => "http://www.example.com" },
        as: :json
    end

    # The JSON import endpoint returns 403 for unauthorized scouts
    assert_response :forbidden
    body = JSON.parse(response.body)
    assert body["error"].present?
  end

  # --- Import: validation errors ---

  test "import rejects missing required fields" do
    sign_in_as(@admin)

    post import_qr_imports_path,
      params: {
        entry: {
          notes: "No uuid or team",
          data: {}
        }
      },
      headers: { "Origin" => "http://www.example.com" },
      as: :json

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_equal "error", body["status"]
  end

  test "import rejects invalid event" do
    sign_in_as(@admin)

    post import_qr_imports_path,
      params: {
        entry: {
          client_uuid: "invalid-event-#{SecureRandom.hex(4)}",
          team_number: @team.team_number,
          event_key: "invalid_key",
          data: {}
        }
      },
      headers: { "Origin" => "http://www.example.com" },
      as: :json

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_equal "error", body["status"]
    assert_includes body["errors"].join, "Invalid event"
  end
end
