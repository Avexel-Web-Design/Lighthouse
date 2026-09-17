require "test_helper"

class ScoutingEntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin_user)
    @event = events(:championship)
    @entry = scouting_entries(:entry_qm1_254)
    sign_in_as(@user)
    select_event(@event)
  end

  # --- Index ---

  test "should get index" do
    get scouting_entries_path
    assert_response :success
  end

  test "scout can get index" do
    sign_out :user
    sign_in_as(users(:scout_user))
    select_event(@event)

    get scouting_entries_path
    assert_response :success
  end

  test "index requires event" do
    reset!
    sign_in_as(@user)

    get scouting_entries_path
    assert_redirected_to events_path
  end

  # --- Show ---

  test "should get show" do
    get scouting_entry_path(@entry)
    assert_response :success
  end

  # --- New ---

  test "should get new" do
    get new_scouting_entry_path
    assert_response :success
    assert_select "option", text: "Q1"
    assert_select "option", text: "Q2"
    assert_select "option", text: "Q3"
    assert_select "option", text: "Q4"
  end

  test "scout can get new" do
    sign_out :user
    sign_in_as(users(:scout_user))
    select_event(@event)

    get new_scouting_entry_path
    assert_response :success
  end

  test "should get replay page" do
    get replay_scouting_entries_path(match_id: matches(:qm4).id)

    assert_response :success
    assert_select "h1", text: "Replay Scout"
    assert_includes response.body, "Q4"
    assert_includes response.body, "Q1"
    assert_includes response.body, "Replay Match Picker"
    assert_select "select[name='match_id']"
    assert_select "select[name='frc_team_id']"
    assert_select "[data-replay-team-grid]"
    assert_select "button[data-replay-team-card='blue-1']"
    assert_select "button[data-replay-team-card='red-1']"
  end

  test "replay page team cards can drive selected team" do
    get replay_scouting_entries_path(match_id: matches(:qm4).id, frc_team_id: frc_teams(:team_254).id)

    assert_response :success
    assert_select "option[value='#{frc_teams(:team_254).id}'][selected='selected']"
    assert_select "button[data-replay-team-card][data-replay-team-selected='true']", count: 1
  end

  test "scout can get replay page" do
    sign_out :user
    sign_in_as(users(:scout_user))
    select_event(@event)

    get replay_scouting_entries_path(match_id: matches(:qm4).id)

    assert_response :success
  end

  test "replay page explains when TBA is not configured" do
    event = Event.create!(name: "Manual Event", tba_key: "2026manual", year: 2026)
    event.matches.create!(comp_level: "qm", set_number: 1, match_number: 1)
    select_event(event)

    original_api_key = ENV["TBA_API_KEY"]
    ENV.delete("TBA_API_KEY")

    begin
      get replay_scouting_entries_path
    ensure
      ENV["TBA_API_KEY"] = original_api_key
    end

    assert_response :success
    assert_includes response.body, "Replay scouting needs a TBA API key"
    assert_includes response.body, "TBA_API_KEY"
  end

  test "replay page route does not require a scouting entry id" do
    assert_routing "/scouting_entries/replay", controller: "scouting_entries", action: "replay"
  end

  test "edit replay entry renders replay workflow" do
    entry = ScoutingEntry.create!(
      user: @user,
      match: matches(:qm4),
      frc_team: frc_teams(:team_254),
      event: @event,
      scouting_mode: :replay,
      video_key: "pastmatchtwo",
      video_type: "youtube",
      data: {},
      client_uuid: "replay-edit-#{SecureRandom.hex(8)}"
    )

    get edit_scouting_entry_path(entry)

    assert_response :success
    assert_select "h1", text: "Replay Scout"
    assert_select "form#replay-scouting-form"
    assert_select "input[name='_method'][value='patch']"
  end

  # --- Create ---

  test "should create scouting entry" do
    match = matches(:qm2)
    team = frc_teams(:team_4414)

    assert_difference("ScoutingEntry.count", 1) do
      post scouting_entries_path, params: {
        scouting_entry: {
          match_id: match.id,
          frc_team_id: team.id,
          notes: "Test entry",
          client_uuid: "create-test-uuid-#{SecureRandom.hex(8)}",
          data: { auton_fuel_made: 3, teleop_fuel_made: 10 }
        }
      }
    end
    assert_redirected_to scouting_entry_path(ScoutingEntry.last)
  end

  test "should create replay scouting entry alongside live entry" do
    match = matches(:qm4)

    assert_difference("ScoutingEntry.count", 1) do
      post scouting_entries_path, params: {
        scouting_entry: {
          scouting_mode: "replay",
          match_id: match.id,
          frc_team_id: frc_teams(:team_254).id,
          video_key: "pastmatchtwo",
          video_type: "youtube",
          notes: "Replay fill-in",
          client_uuid: "replay-create-uuid-#{SecureRandom.hex(8)}",
          data: { auton_fuel_made: 2, teleop_fuel_made: 5 }
        }
      }
    end

    entry = ScoutingEntry.last
    assert entry.replay?
    assert_equal "pastmatchtwo", entry.video_key
    assert_redirected_to scouting_entry_path(entry)
  end

  test "replay create failure preserves selected video source" do
    post scouting_entries_path, params: {
      scouting_entry: {
        scouting_mode: "replay",
        match_id: matches(:qm4).id,
        video_key: "pastmatchtwo",
        video_type: "youtube",
        notes: "Missing team should fail",
        client_uuid: "replay-failure-#{SecureRandom.hex(8)}",
        data: { auton_fuel_made: 2 }
      }
    }

    assert_response :unprocessable_entity
    assert_select "form#replay-scouting-form input[name='scouting_entry[video_key]'][value='pastmatchtwo']"
  end

  test "updating replay entry keeps replay match and team assignment locked" do
    entry = ScoutingEntry.create!(
      user: @user,
      match: matches(:qm4),
      frc_team: frc_teams(:team_254),
      event: @event,
      scouting_mode: :replay,
      video_key: "pastmatchtwo",
      video_type: "youtube",
      notes: "Original replay note",
      data: {},
      client_uuid: "replay-lock-#{SecureRandom.hex(8)}"
    )

    patch scouting_entry_path(entry), params: {
      scouting_entry: {
        scouting_mode: "replay",
        match_id: matches(:qm3).id,
        frc_team_id: frc_teams(:team_6328).id,
        video_key: "different-video",
        notes: "Updated replay note",
        data: { auton_fuel_made: 1 }
      }
    }

    assert_redirected_to scouting_entry_path(entry)

    entry.reload
    assert_equal matches(:qm4).id, entry.match_id
    assert_equal frc_teams(:team_254).id, entry.frc_team_id
    assert_equal "pastmatchtwo", entry.video_key
    assert_equal "Updated replay note", entry.notes
  end

  test "scout can create scouting entry" do
    sign_out :user
    sign_in_as(users(:scout_user))
    select_event(@event)

    match = matches(:qm2)
    team = frc_teams(:team_4414)

    assert_difference("ScoutingEntry.count", 1) do
      post scouting_entries_path, params: {
        scouting_entry: {
          match_id: match.id,
          frc_team_id: team.id,
          notes: "Scout test entry",
          client_uuid: "scout-create-uuid-#{SecureRandom.hex(8)}",
          data: { auton_fuel_made: 1 }
        }
      }
    end
    assert_redirected_to scouting_entry_path(ScoutingEntry.last)
  end

  test "create with duplicate client_uuid redirects to existing" do
    existing = scouting_entries(:entry_qm1_254)

    assert_no_difference("ScoutingEntry.count") do
      post scouting_entries_path, params: {
        scouting_entry: {
          match_id: existing.match_id,
          frc_team_id: existing.frc_team_id,
          notes: "Duplicate",
          client_uuid: existing.client_uuid
        }
      }
    end
    assert_redirected_to scouting_entry_path(existing)
  end

  test "show includes scout next match for live entries" do
    # Travel to during the event so upcoming matches exist for "next match"
    travel_to Date.new(2026, 4, 15) do
      get scouting_entry_path(scouting_entries(:entry_qm1_254))

      assert_response :success
      assert_select "a", text: "Scout Next Match"
    end
  end

  test "admin can approve flagged entry" do
    @entry.update!(status: :flagged)

    post approve_scouting_entry_path(@entry)

    assert_redirected_to scouting_entry_path(@entry)
    @entry.reload
    assert @entry.approved?
  end

  test "admin cannot approve submitted entry" do
    @entry.update!(status: :submitted)

    post approve_scouting_entry_path(@entry)

    assert_redirected_to scouting_entry_path(@entry)
    @entry.reload
    assert @entry.submitted?
  end

  test "scout cannot approve flagged entry" do
    @entry.update!(status: :flagged)
    sign_out :user
    sign_in_as(users(:scout_user))
    select_event(@event)

    post approve_scouting_entry_path(@entry)

    assert_response :redirect
    @entry.reload
    assert @entry.flagged?
  end

  # --- Sync with LWW ---

  test "sync creates new entry" do
    uuid = "sync-new-#{SecureRandom.hex(8)}"
    team = frc_teams(:team_4414)
    match = matches(:qm2)

    assert_difference("ScoutingEntry.count", 1) do
      post sync_scouting_entries_path,
        params: {
          entries: [
            {
              client_uuid: uuid,
              match_id: match.id,
              frc_team_id: team.id,
              event_id: @event.id,
              notes: "Synced entry",
              data: { auton_fuel_made: 3 }
            }
          ]
        },
        headers: { "Origin" => "http://www.example.com" },
        as: :json
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "created", body["results"][0]["status"]
  end

  test "sync returns existing when duplicate uuid has no updated_at" do
    existing = scouting_entries(:entry_qm1_254)

    assert_no_difference("ScoutingEntry.count") do
      post sync_scouting_entries_path,
        params: {
          entries: [
            {
              client_uuid: existing.client_uuid,
              match_id: existing.match_id,
              frc_team_id: existing.frc_team_id,
              event_id: existing.event_id,
              notes: "Should not overwrite",
              data: { auton_fuel_made: 99 }
            }
          ]
        },
        headers: { "Origin" => "http://www.example.com" },
        as: :json
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "existing", body["results"][0]["status"]

    existing.reload
    assert_not_equal 99, existing.data["auton_fuel_made"]
  end

  test "sync updates existing entry when incoming timestamp is newer (LWW)" do
    existing = scouting_entries(:entry_qm1_254)
    future_time = (existing.updated_at + 1.hour).iso8601

    assert_no_difference("ScoutingEntry.count") do
      post sync_scouting_entries_path,
        params: {
          entries: [
            {
              client_uuid: existing.client_uuid,
              match_id: existing.match_id,
              frc_team_id: existing.frc_team_id,
              event_id: existing.event_id,
              notes: "Updated via LWW sync",
              updated_at: future_time,
              data: { auton_fuel_made: 77, teleop_fuel_made: 33 }
            }
          ]
        },
        headers: { "Origin" => "http://www.example.com" },
        as: :json
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "updated", body["results"][0]["status"]

    existing.reload
    assert_equal 77, existing.data["auton_fuel_made"]
    assert_equal 33, existing.data["teleop_fuel_made"]
    assert_equal "Updated via LWW sync", existing.notes
  end

  test "sync keeps admin approved status when incoming payload updates entry" do
    existing = scouting_entries(:entry_qm1_254)
    existing.update!(status: :approved)
    future_time = (existing.updated_at + 1.hour).iso8601

    post sync_scouting_entries_path,
      params: {
        entries: [
          {
            client_uuid: existing.client_uuid,
            match_id: existing.match_id,
            frc_team_id: existing.frc_team_id,
            event_id: existing.event_id,
            notes: "Approved entry updated",
            updated_at: future_time,
            status: :flagged,
            data: { auton_fuel_made: 70 }
          }
        ]
      },
      headers: { "Origin" => "http://www.example.com" },
      as: :json

    assert_response :success
    existing.reload
    assert existing.approved?
    assert_equal 70, existing.data["auton_fuel_made"]
  end

  test "sync skips update when server copy is newer" do
    existing = scouting_entries(:entry_qm1_254)
    old_time = (existing.updated_at - 1.hour).iso8601

    post sync_scouting_entries_path,
      params: {
        entries: [
          {
            client_uuid: existing.client_uuid,
            match_id: existing.match_id,
            frc_team_id: existing.frc_team_id,
            event_id: existing.event_id,
            notes: "Should not overwrite",
            updated_at: old_time,
            data: { auton_fuel_made: 88 }
          }
        ]
      },
      headers: { "Origin" => "http://www.example.com" },
      as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "existing", body["results"][0]["status"]

    existing.reload
    assert_not_equal 88, existing.data["auton_fuel_made"]
  end

  # --- Authentication ---

  test "unauthenticated user is redirected" do
    sign_out :user

    get scouting_entries_path
    assert_redirected_to new_user_session_path
  end
end
