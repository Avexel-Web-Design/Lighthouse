require "test_helper"

class ScoutingEntryTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActionCable::TestHelper

  test "committed mutations broadcast once and enqueue summary refreshes" do
    entry = ScoutingEntry.new(event: events(:championship), frc_team: frc_teams(:team_254),
                              user: users(:admin_user), data: {}, client_uuid: "")
    stream = "scouting_entries_event_#{entry.event_id}"
    [ [ "prepend", -> { entry.save! } ], [ "replace", -> { entry.update!(notes: "Updated") } ],
      [ "remove", -> { entry.destroy! } ] ].each do |action, mutation|
      messages = capture_broadcasts(stream) do
        assert_enqueued_jobs 1, only: RefreshSummariesJob do
          assert_enqueued_with(job: RefreshSummariesJob, args: [ entry.event_id ], &mutation)
        end
      end
      assert_equal 1, messages.size
      assert_includes messages.first, "action=\"#{action}\""
    end
    assert_nil entry.client_uuid
  end

  test "rolled back entries neither broadcast nor enqueue refreshes" do
    stream = "scouting_entries_event_#{events(:championship).id}"
    assert_no_broadcasts(stream) do
      assert_no_enqueued_jobs only: RefreshSummariesJob do
        ScoutingEntry.transaction(requires_new: true) do
          ScoutingEntry.create!(event: events(:championship), frc_team: frc_teams(:team_254),
                                user: users(:admin_user), data: {})
          raise ActiveRecord::Rollback
        end
      end
    end
  end

  test "integer parsing distinguishes missing and malformed values from zero" do
    entry = ScoutingEntry.new(data: {})
    [ nil, true, false, [], {}, "bad", "1.5", 1.5 ].each do |value|
      entry.data = { "auton_fuel_made" => value }
      assert_nil entry.send(:dig_int, "auton_fuel_made")
      assert_equal 0, entry.total_fuel_made
      assert_equal 0, entry.auton_points
    end
    [ [ 0, 0 ], [ "0", 0 ], [ "12", 12 ], [ "-2", -2 ] ].each do |value, expected|
      entry.data = { "auton_fuel_made" => value }
      assert_equal expected, entry.send(:dig_int, "auton_fuel_made")
    end
    entry.data = nil
    assert_equal 0, entry.total_points
    assert_equal 0, entry.defense_rating
  end

  # --- Validations ---

  test "valid scouting entry from fixtures" do
    assert scouting_entries(:entry_qm1_254).valid?
    assert scouting_entries(:entry_qm1_1678).valid?
    assert scouting_entries(:entry_qm2_254).valid?
    assert scouting_entries(:entry_qm2_1678).valid?
  end

  test "requires unique client_uuid" do
    duplicate = ScoutingEntry.new(
      user: users(:admin_user),
      frc_team: frc_teams(:team_254),
      event: events(:championship),
      client_uuid: "scout-entry-uuid-0001"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:client_uuid], "has already been taken"
  end

  test "allows nil client_uuid" do
    entry = ScoutingEntry.new(
      user: users(:admin_user),
      frc_team: frc_teams(:team_254),
      event: events(:championship),
      data: {},
      client_uuid: nil
    )
    entry.valid?
    assert_empty entry.errors[:client_uuid]
  end

  test "allows multiple nil client_uuids" do
    ScoutingEntry.create!(
      user: users(:admin_user),
      frc_team: frc_teams(:team_254),
      event: events(:championship),
      data: {},
      client_uuid: nil
    )
    entry2 = ScoutingEntry.new(
      user: users(:lead_user),
      frc_team: frc_teams(:team_1678),
      event: events(:championship),
      data: {},
      client_uuid: nil
    )
    assert entry2.valid?
  end

  test "allows live and replay entries for same user match and team" do
    entry = ScoutingEntry.new(
      user: users(:admin_user),
      match: matches(:qm4),
      frc_team: frc_teams(:team_254),
      event: events(:championship),
      scouting_mode: :replay,
      data: {},
      client_uuid: "duplicate-mode-test"
    )

    assert entry.valid?
  end

  # --- Associations ---

  test "belongs to user" do
    assert_equal users(:admin_user), scouting_entries(:entry_qm1_254).user
  end

  test "belongs to match (optional)" do
    assert_equal matches(:qm1), scouting_entries(:entry_qm1_254).match
  end

  test "belongs to frc_team" do
    assert_equal frc_teams(:team_254), scouting_entries(:entry_qm1_254).frc_team
  end

  test "belongs to event" do
    assert_equal events(:championship), scouting_entries(:entry_qm1_254).event
  end

  # --- Enums ---

  test "status enum values" do
    assert_equal({ "submitted" => 0, "flagged" => 1, "rejected" => 2, "approved" => 3 }, ScoutingEntry.statuses)
  end

  test "scouting_mode enum values" do
    assert_equal({ "live" => 0, "replay" => 1 }, ScoutingEntry.scouting_modes)
  end

  test "entry_qm1_254 is submitted" do
    assert scouting_entries(:entry_qm1_254).submitted?
  end

  test "mode_label returns replay or live" do
    assert_equal "Live", scouting_entries(:entry_qm1_254).mode_label
    assert_equal "Replay", ScoutingEntry.new(scouting_mode: :replay).mode_label
  end

  test "counted? returns true for approved entries" do
    entry = scouting_entries(:entry_qm1_254)
    entry.status = :approved

    assert entry.counted?
  end

  test "status_label returns admin approved for approved entries" do
    entry = scouting_entries(:entry_qm1_254)
    entry.status = :approved

    assert_equal "Admin Approved", entry.status_label
  end

  # --- Scoring concern constants ---

  test "FUEL_POINT_VALUE is 1" do
    assert_equal 1, ScoutingEntry::FUEL_POINT_VALUE
  end

  test "CLIMB_POINTS hash" do
    expected = { "None" => 0, "L1" => 10, "L2" => 20, "L3" => 30 }
    assert_equal expected, ScoutingEntry::CLIMB_POINTS
  end

  test "AUTON_CLIMB_POINTS is 15" do
    assert_equal 15, ScoutingEntry::AUTON_CLIMB_POINTS
  end

  # --- Computed Methods: entry_qm1_254 ---
  # Data: auton_fuel_made=5, auton_fuel_missed=1, teleop_fuel_made=12, teleop_fuel_missed=3,
  #       endgame is reserved for climb/review, so endgame fuel stays at 0, endgame_climb=L3, auton_climb=true

  test "total_fuel_made for entry_qm1_254" do
    entry = scouting_entries(:entry_qm1_254)
    # 5 + 12 + 0 = 17
    assert_equal 17, entry.total_fuel_made
  end

  test "total_fuel_missed for entry_qm1_254" do
    entry = scouting_entries(:entry_qm1_254)
    # 1 + 3 + 0 = 4
    assert_equal 4, entry.total_fuel_missed
  end

  test "fuel_accuracy for entry_qm1_254" do
    entry = scouting_entries(:entry_qm1_254)
    # 17 / (17 + 4) * 100 = 17/21*100 = 80.952... -> 81.0
    assert_equal 81.0, entry.fuel_accuracy
  end

  test "total_points for entry_qm1_254" do
    entry = scouting_entries(:entry_qm1_254)
    # fuel: 17 * 1 = 17
    # auton_climb: true -> +15
    # endgame_climb: L3 -> +30
    # total: 17 + 15 + 30 = 62
    assert_equal 62, entry.total_points
  end

  # --- Computed Methods: entry_qm1_1678 ---
  # Data: auton_fuel_made=3, auton_fuel_missed=2, teleop_fuel_made=10, teleop_fuel_missed=4,
  #       endgame is reserved for climb/review, so endgame fuel stays at 0, endgame_climb=L2, auton_climb=false

  test "total_fuel_made for entry_qm1_1678" do
    entry = scouting_entries(:entry_qm1_1678)
    # 3 + 10 + 0 = 13
    assert_equal 13, entry.total_fuel_made
  end

  test "total_fuel_missed for entry_qm1_1678" do
    entry = scouting_entries(:entry_qm1_1678)
    # 2 + 4 + 0 = 6
    assert_equal 6, entry.total_fuel_missed
  end

  test "fuel_accuracy for entry_qm1_1678" do
    entry = scouting_entries(:entry_qm1_1678)
    # 13 / (13 + 6) * 100 = 13/19*100 = 68.421... -> 68.4
    assert_equal 68.4, entry.fuel_accuracy
  end

  test "total_points for entry_qm1_1678" do
    entry = scouting_entries(:entry_qm1_1678)
    # fuel: 13 * 1 = 13
    # auton_climb: false -> 0
    # endgame_climb: L2 -> +20
    # total: 13 + 0 + 20 = 33
    assert_equal 33, entry.total_points
  end

  # --- Computed Methods: entry_qm2_254 ---
  # Data: auton_fuel_made=6, auton_fuel_missed=0, teleop_fuel_made=14, teleop_fuel_missed=2,
  #       endgame is reserved for climb/review, so endgame fuel stays at 0, endgame_climb=L3, auton_climb=true

  test "total_fuel_made for entry_qm2_254" do
    entry = scouting_entries(:entry_qm2_254)
    # 6 + 14 + 0 = 20
    assert_equal 20, entry.total_fuel_made
  end

  test "total_fuel_missed for entry_qm2_254" do
    entry = scouting_entries(:entry_qm2_254)
    # 0 + 2 + 0 = 2
    assert_equal 2, entry.total_fuel_missed
  end

  test "fuel_accuracy for entry_qm2_254" do
    entry = scouting_entries(:entry_qm2_254)
    # 20 / (20 + 2) * 100 = 20/22*100 = 90.909... -> 90.9
    assert_equal 90.9, entry.fuel_accuracy
  end

  test "total_points for entry_qm2_254" do
    entry = scouting_entries(:entry_qm2_254)
    # fuel: 20 * 1 = 20
    # auton_climb: true -> +15
    # endgame_climb: L3 -> +30
    # total: 20 + 15 + 30 = 65
    assert_equal 65, entry.total_points
  end

  # --- Computed Methods: entry_qm2_1678 ---
  # Data: auton_fuel_made=4, auton_fuel_missed=1, teleop_fuel_made=11, teleop_fuel_missed=3,
  #       endgame is reserved for climb/review, so endgame fuel stays at 0, endgame_climb=L2, auton_climb=true

  test "total_fuel_made for entry_qm2_1678" do
    entry = scouting_entries(:entry_qm2_1678)
    # 4 + 11 + 0 = 15
    assert_equal 15, entry.total_fuel_made
  end

  test "total_fuel_missed for entry_qm2_1678" do
    entry = scouting_entries(:entry_qm2_1678)
    # 1 + 3 + 0 = 4
    assert_equal 4, entry.total_fuel_missed
  end

  test "fuel_accuracy for entry_qm2_1678" do
    entry = scouting_entries(:entry_qm2_1678)
    # 15 / (15 + 4) * 100 = 15/19*100 = 78.947... -> 78.9
    assert_equal 78.9, entry.fuel_accuracy
  end

  test "total_points for entry_qm2_1678" do
    entry = scouting_entries(:entry_qm2_1678)
    # fuel: 15 * 1 = 15
    # auton_climb: true -> +15
    # endgame_climb: L2 -> +20
    # total: 15 + 15 + 20 = 50
    assert_equal 50, entry.total_points
  end

  # --- Edge cases for computed methods ---

  test "fuel_accuracy returns 0.0 when no attempts" do
    entry = ScoutingEntry.new(data: {}, event: events(:championship), frc_team: frc_teams(:team_254), user: users(:admin_user))
    assert_equal 0.0, entry.fuel_accuracy
  end

  test "total_points with no data" do
    entry = ScoutingEntry.new(data: {}, event: events(:championship), frc_team: frc_teams(:team_254), user: users(:admin_user))
    assert_equal 0, entry.total_points
  end

  test "total_points with unknown climb level" do
    entry = ScoutingEntry.new(
      data: { "endgame_climb" => "Unknown", "auton_climb" => false },
      event: events(:championship),
      frc_team: frc_teams(:team_254),
      user: users(:admin_user)
    )
    assert_equal 0, entry.total_points
  end

  # --- Defence Rating ---

  test "defense_rating returns 0 when not present" do
    entry = ScoutingEntry.new(data: {}, event: events(:championship), frc_team: frc_teams(:team_254), user: users(:admin_user))
    assert_equal 0, entry.defense_rating
  end

  test "defense_rating returns value from JSONB data" do
    entry = ScoutingEntry.new(
      data: { "defense_rating" => 4 },
      event: events(:championship),
      frc_team: frc_teams(:team_254),
      user: users(:admin_user)
    )
    assert_equal 4, entry.defense_rating
  end

  test "auton_actions returns empty array when not present" do
    entry = ScoutingEntry.new(data: {}, event: events(:championship), frc_team: frc_teams(:team_254), user: users(:admin_user))
    assert_equal [], entry.auton_actions
  end

  test "auton_actions returns data from JSONB" do
    entry = ScoutingEntry.new(
      data: { "auton_actions" => [ "move", "shoot", "intake" ] },
      event: events(:championship),
      frc_team: frc_teams(:team_254),
      user: users(:admin_user)
    )
    assert_equal [ "move", "shoot", "intake" ], entry.auton_actions
  end

  # --- Class Methods ---

  test "from_offline_data builds a new ScoutingEntry" do
    params = {
      user_id: users(:admin_user).id,
      match_id: matches(:qm1).id,
      frc_team_id: frc_teams(:team_254).id,
      event_id: events(:championship).id,
      data: { "auton_fuel_made" => 10 },
      notes: "Offline entry",
      photo_url: "https://example.com/photo.jpg",
      client_uuid: "offline-uuid-001",
      status: :submitted,
      scouting_mode: :replay,
      video_key: "pastmatchone?t=15",
      video_type: "youtube"
    }
    entry = ScoutingEntry.from_offline_data(params)

    assert entry.new_record?
    assert_equal users(:admin_user).id, entry.user_id
    assert_equal matches(:qm1).id, entry.match_id
    assert_equal frc_teams(:team_254).id, entry.frc_team_id
    assert_equal events(:championship).id, entry.event_id
    assert_equal({ "auton_fuel_made" => 10 }, entry.data)
    assert_equal "Offline entry", entry.notes
    assert_equal "https://example.com/photo.jpg", entry.photo_url
    assert_equal "offline-uuid-001", entry.client_uuid
    assert entry.replay?
    assert_equal "pastmatchone?t=15", entry.video_key
    assert_equal "youtube", entry.video_type
  end

  test "from_offline_data defaults to empty hash for data and submitted status" do
    params = {
      user_id: users(:admin_user).id,
      frc_team_id: frc_teams(:team_254).id,
      event_id: events(:championship).id
    }
    entry = ScoutingEntry.from_offline_data(params)
    assert_equal({}, entry.data)
    assert entry.live?
  end

  test "sync_status ignores approved status from clients" do
    assert_equal :submitted, ScoutingEntry.sync_status(:approved)
  end
end
