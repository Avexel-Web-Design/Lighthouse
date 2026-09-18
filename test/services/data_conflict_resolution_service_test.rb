# frozen_string_literal: true

require "test_helper"

class DataConflictResolutionServiceTest < ActiveSupport::TestCase
  setup do
    @conflict = data_conflicts(:conflict_qm1_254_climb)
    @admin = users(:admin_user)
  end

  test "raises ArgumentError when resolution value is blank" do
    assert_raises(ArgumentError) do
      DataConflictResolutionService.new(@conflict, resolution_value: "", resolved_by: @admin).resolve!
    end

    assert_raises(ArgumentError) do
      DataConflictResolutionService.new(@conflict, resolution_value: nil, resolved_by: @admin).resolve!
    end
  end

  test "resolves conflict and applies value to entries" do
    DataConflictResolutionService.new(@conflict, resolution_value: "L2", resolved_by: @admin).resolve!

    @conflict.reload
    assert @conflict.resolved?
    assert_equal @admin, @conflict.resolved_by
    assert_equal "L2", @conflict.resolution_value

    assert_equal "L2", scouting_entries(:entry_qm1_254).reload.data["endgame_climb"]
  end

  test "casts numeric resolution values to integers" do
    conflict = DataConflict.create!(
      event: events(:championship),
      frc_team: frc_teams(:team_254),
      match: matches(:qm1),
      field_name: "auton_fuel_made",
      values: { users(:admin_user).id => 5, users(:lead_user).id => 3 }
    )

    DataConflictResolutionService.new(conflict, resolution_value: "4", resolved_by: @admin).resolve!

    assert_equal 4, scouting_entries(:entry_qm1_254).reload.data["auton_fuel_made"]
    assert_equal "4", conflict.reload.resolution_value
  end

  test "casts boolean resolution values" do
    conflict = DataConflict.create!(
      event: events(:championship),
      frc_team: frc_teams(:team_254),
      match: matches(:qm1),
      field_name: "auton_climb",
      values: { users(:admin_user).id => true, users(:lead_user).id => false }
    )

    DataConflictResolutionService.new(conflict, resolution_value: "true", resolved_by: @admin).resolve!

    assert_equal true, scouting_entries(:entry_qm1_254).reload.data["auton_climb"]
  end

  test "approves flagged entry when approved_entry_id is given" do
    scouting_entries(:entry_qm1_254).update!(status: :flagged)

    DataConflictResolutionService.new(
      @conflict,
      resolution_value: "L3",
      resolved_by: @admin,
      approved_entry_id: scouting_entries(:entry_qm1_254).id
    ).resolve!

    assert scouting_entries(:entry_qm1_254).reload.approved?
    assert @conflict.reload.resolved?
  end

  test "raises when approving a non-flagged entry" do
    assert scouting_entries(:entry_qm1_254).submitted?

    assert_raises(ArgumentError) do
      DataConflictResolutionService.new(
        @conflict,
        resolution_value: "L3",
        resolved_by: @admin,
        approved_entry_id: scouting_entries(:entry_qm1_254).id
      ).resolve!
    end

    assert_not @conflict.reload.resolved?
  end

  test "skips rejected entries when applying resolution" do
    scouting_entries(:entry_qm1_254).update!(status: :rejected)

    DataConflictResolutionService.new(@conflict, resolution_value: "L2", resolved_by: @admin).resolve!

    assert_equal "L3", scouting_entries(:entry_qm1_254).reload.data["endgame_climb"]
    assert @conflict.reload.resolved?
  end
end
