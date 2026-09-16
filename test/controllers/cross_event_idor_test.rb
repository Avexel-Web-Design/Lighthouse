require "test_helper"

class CrossEventIdorTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    @event = events(:championship)
    sign_in_as(@admin)
    select_event(@event)
  end

  test "cannot access scouting entry from other event" do
    other_event = Event.create!(name: "Other", tba_key: "2026x#{SecureRandom.hex(4)}", year: 2026)
    other_match = other_event.matches.create!(comp_level: "qm", set_number: 1, match_number: 1)
    other_entry = ScoutingEntry.create!(
      user: @admin,
      event: other_event,
      match: other_match,
      frc_team: frc_teams(:team_254),
      data: {},
      client_uuid: "idor-#{SecureRandom.hex(8)}"
    )

    get scouting_entry_path(other_entry)
    assert_response :missing
  end

  test "cannot access pick list from other event" do
    other_event = Event.create!(name: "Other Picks", tba_key: "2026p#{SecureRandom.hex(4)}", year: 2026)
    other_list = PickList.create!(
      name: "Other",
      event: other_event,
      user: @admin,
      entries: []
    )

    get pick_list_path(other_list)
    assert_response :missing
  end

  test "cannot resolve data conflict from other event" do
    other_event = Event.create!(name: "Other Conflict", tba_key: "2026c#{SecureRandom.hex(4)}", year: 2026)
    other_match = other_event.matches.create!(comp_level: "qm", set_number: 1, match_number: 1)
    conflict = DataConflict.create!(
      event: other_event,
      frc_team: frc_teams(:team_254),
      match: other_match,
      field_name: "endgame_climb",
      values: {},
      resolved: false
    )

    post resolve_data_conflict_path(conflict), params: { resolution: "L3" }
    assert_response :missing
  end
end
