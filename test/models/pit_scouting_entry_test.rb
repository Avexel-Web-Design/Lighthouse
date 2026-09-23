require "test_helper"

class PitScoutingEntryTest < ActiveSupport::TestCase
  # --- Validations ---

  test "valid pit scouting entry from fixtures" do
    assert pit_scouting_entries(:pit_254).valid?
    assert pit_scouting_entries(:pit_1678).valid?
  end

  test "requires unique client_uuid" do
    duplicate = PitScoutingEntry.new(
      user: users(:admin_user),
      frc_team: frc_teams(:team_254),
      event: events(:championship),
      client_uuid: "pit-entry-uuid-0001"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:client_uuid], "has already been taken"
  end

  test "allows nil client_uuid" do
    entry = PitScoutingEntry.new(
      user: users(:admin_user),
      frc_team: frc_teams(:team_254),
      event: events(:championship),
      data: {},
      client_uuid: nil
    )
    entry.valid?
    assert_empty entry.errors[:client_uuid]
  end

  # --- Associations ---

  test "belongs to event" do
    assert_equal events(:championship), pit_scouting_entries(:pit_254).event
  end

  test "belongs to frc_team" do
    assert_equal frc_teams(:team_254), pit_scouting_entries(:pit_254).frc_team
  end

  test "belongs to user" do
    assert_equal users(:scout_user), pit_scouting_entries(:pit_254).user
  end

  # --- Enums ---

  test "status enum values" do
    assert_equal({ "submitted" => 0, "flagged" => 1, "rejected" => 2, "approved" => 3 }, PitScoutingEntry.statuses)
  end

  test "pit_254 is submitted" do
    assert pit_scouting_entries(:pit_254).submitted?
  end

  # --- Computed Methods: pit_254 ---

  test "drivetrain for pit_254" do
    assert_equal "Swerve", pit_scouting_entries(:pit_254).drivetrain
  end

  test "robot_width for pit_254" do
    assert_equal 28, pit_scouting_entries(:pit_254).robot_width
  end

  test "robot_length for pit_254" do
    assert_equal 30, pit_scouting_entries(:pit_254).robot_length
  end

  test "robot_height for pit_254" do
    assert_equal 42, pit_scouting_entries(:pit_254).robot_height
  end

  test "robot_weight for pit_254" do
    assert_equal 120, pit_scouting_entries(:pit_254).robot_weight
  end

  test "drive_motor for pit_254" do
    assert_equal "Kraken X60", pit_scouting_entries(:pit_254).drive_motor
  end

  test "pivot_motor for pit_254" do
    assert_equal "NEO 550", pit_scouting_entries(:pit_254).pivot_motor
  end

  test "intake_types for pit_254" do
    assert_equal [ "over_bumper" ], pit_scouting_entries(:pit_254).intake_types
  end

  test "intake_mechanism for pit_254" do
    assert_equal "Slapdown", pit_scouting_entries(:pit_254).intake_mechanism
  end

  test "shooter_types for pit_254" do
    assert_equal [ "Turret" ], pit_scouting_entries(:pit_254).shooter_types
  end

  test "shooter_hood for pit_254" do
    assert_equal "Adjustable", pit_scouting_entries(:pit_254).shooter_hood
  end

  test "climber_levels for pit_254" do
    assert_equal [ "L2", "L3" ], pit_scouting_entries(:pit_254).climber_levels
  end

  test "climber_type for pit_254" do
    assert_equal "Elevator", pit_scouting_entries(:pit_254).climber_type
  end

  test "strengths for pit_254" do
    assert_equal "Fast cycle time, reliable climber", pit_scouting_entries(:pit_254).strengths
  end

  test "weaknesses for pit_254" do
    assert_equal "Occasional intake jams", pit_scouting_entries(:pit_254).weaknesses
  end

  # --- Computed Methods: pit_1678 ---

  test "drivetrain for pit_1678" do
    assert_equal "Swerve", pit_scouting_entries(:pit_1678).drivetrain
  end

  test "robot_weight for pit_1678" do
    assert_equal 118, pit_scouting_entries(:pit_1678).robot_weight
  end

  test "intake_types for pit_1678" do
    assert_equal [ "over_bumper", "through_bumper" ], pit_scouting_entries(:pit_1678).intake_types
  end

  test "indexer for pit_1678" do
    assert_equal "Spindexer", pit_scouting_entries(:pit_1678).indexer
  end

  test "shooter_types for pit_1678" do
    assert_equal [ "Dual Shooter" ], pit_scouting_entries(:pit_1678).shooter_types
  end

  test "climber_levels for pit_1678" do
    assert_equal [ "L1", "L2", "L3" ], pit_scouting_entries(:pit_1678).climber_levels
  end

  test "climber_type for pit_1678" do
    assert_equal "Windmill", pit_scouting_entries(:pit_1678).climber_type
  end

  test "strengths for pit_1678" do
    assert_equal "Consistent autonomous, great defense", pit_scouting_entries(:pit_1678).strengths
  end

  test "weaknesses for pit_1678" do
    assert_equal "Slower cycle time", pit_scouting_entries(:pit_1678).weaknesses
  end

  # --- Edge cases for computed methods ---

  test "drivetrain returns Unknown when not present" do
    entry = PitScoutingEntry.new(data: {}, event: events(:championship), frc_team: frc_teams(:team_254), user: users(:admin_user))
    assert_equal "Unknown", entry.drivetrain
  end

  test "robot_width returns nil when not present" do
    entry = PitScoutingEntry.new(data: {}, event: events(:championship), frc_team: frc_teams(:team_254), user: users(:admin_user))
    assert_nil entry.robot_width
  end

  test "intake_types returns empty array when not present" do
    entry = PitScoutingEntry.new(data: {}, event: events(:championship), frc_team: frc_teams(:team_254), user: users(:admin_user))
    assert_equal [], entry.intake_types
  end

  test "shooter_types returns empty array when not present" do
    entry = PitScoutingEntry.new(data: {}, event: events(:championship), frc_team: frc_teams(:team_254), user: users(:admin_user))
    assert_equal [], entry.shooter_types
  end

  test "climber_levels returns empty array when not present" do
    entry = PitScoutingEntry.new(data: {}, event: events(:championship), frc_team: frc_teams(:team_254), user: users(:admin_user))
    assert_equal [], entry.climber_levels
  end

  test "auton_paths returns empty array when not present" do
    entry = PitScoutingEntry.new(data: {}, event: events(:championship), frc_team: frc_teams(:team_254), user: users(:admin_user))
    assert_equal [], entry.auton_paths
  end

  test "strengths returns empty string when not present" do
    entry = PitScoutingEntry.new(data: {}, event: events(:championship), frc_team: frc_teams(:team_254), user: users(:admin_user))
    assert_equal "", entry.strengths
  end

  test "weaknesses returns empty string when not present" do
    entry = PitScoutingEntry.new(data: {}, event: events(:championship), frc_team: frc_teams(:team_254), user: users(:admin_user))
    assert_equal "", entry.weaknesses
  end

  # --- Display helpers ---

  test "intake_mechanism_display returns mechanism name" do
    entry = PitScoutingEntry.new(data: { "intake_mechanism" => "Slapdown" })
    assert_equal "Slapdown", entry.intake_mechanism_display
  end

  test "intake_mechanism_display returns other text when Other" do
    entry = PitScoutingEntry.new(data: { "intake_mechanism" => "Other", "intake_mechanism_other" => "Custom arm" })
    assert_equal "Custom arm", entry.intake_mechanism_display
  end

  test "indexer_display returns indexer name" do
    entry = PitScoutingEntry.new(data: { "indexer" => "Spindexer" })
    assert_equal "Spindexer", entry.indexer_display
  end

  test "indexer_display returns other text when Other" do
    entry = PitScoutingEntry.new(data: { "indexer" => "Other", "indexer_other" => "Custom belt" })
    assert_equal "Custom belt", entry.indexer_display
  end

  # --- Class Methods ---

  test "from_offline_data builds a new PitScoutingEntry" do
    params = {
      user_id: users(:admin_user).id,
      event_id: events(:championship).id,
      frc_team_id: frc_teams(:team_118).id,
      data: { "drivetrain" => "tank" },
      notes: "Offline pit scout",
      client_uuid: "offline-pit-uuid-001",
      status: :submitted
    }
    entry = PitScoutingEntry.from_offline_data(params)

    assert entry.new_record?
    assert_equal users(:admin_user).id, entry.user_id
    assert_equal events(:championship).id, entry.event_id
    assert_equal frc_teams(:team_118).id, entry.frc_team_id
    assert_equal({ "drivetrain" => "tank" }, entry.data)
    assert_equal "Offline pit scout", entry.notes
    assert_equal "offline-pit-uuid-001", entry.client_uuid
  end

  test "from_offline_data defaults to empty hash for data" do
    params = {
      user_id: users(:admin_user).id,
      event_id: events(:championship).id,
      frc_team_id: frc_teams(:team_254).id
    }
    entry = PitScoutingEntry.from_offline_data(params)
    assert_equal({}, entry.data)
  end
end
