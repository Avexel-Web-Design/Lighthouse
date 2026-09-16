require "test_helper"

class PitScoutingDiscrepancyServiceTest < ActiveSupport::TestCase
  setup do
    @event = events(:championship)
    @team = frc_teams(:team_254)
  end

  # --- Edge cases ---

  test "returns empty with fewer than two entries" do
    assert_empty PitScoutingDiscrepancyService.new([]).discrepancies
    assert_empty PitScoutingDiscrepancyService.new([ pit_scouting_entries(:pit_254) ]).discrepancies
  end

  test "returns empty when entries agree" do
    other = build_entry(data: pit_scouting_entries(:pit_254).data.deep_dup)
    discrepancies = PitScoutingDiscrepancyService.new([ pit_scouting_entries(:pit_254), other ]).discrepancies
    assert_empty discrepancies
  end

  # --- String fields ---

  test "flags differing drivetrain" do
    other = build_entry(data: { "drivetrain" => "Tank" })
    discrepancies = PitScoutingDiscrepancyService.new([ pit_scouting_entries(:pit_254), other ]).discrepancies

    drivetrain = discrepancies.find { |d| d[:key] == "drivetrain" }
    assert_not_nil drivetrain
    assert_equal "Drivetrain", drivetrain[:label]
    assert_equal 2, drivetrain[:reports].size
    assert_includes drivetrain[:reports].map { |r| r[:display] }, "Swerve"
    assert_includes drivetrain[:reports].map { |r| r[:display] }, "Tank"
  end

  test "blank and nil string values agree" do
    first = build_entry(data: {})
    second = build_entry(data: { "drive_motor" => "  " })
    discrepancies = PitScoutingDiscrepancyService.new([ first, second ]).discrepancies

    assert_nil discrepancies.find { |d| d[:key] == "drive_motor" }
  end

  # --- Numeric fields ---

  test "numeric string and integer agree" do
    first = build_entry(data: { "robot_weight" => 120 })
    second = build_entry(data: { "robot_weight" => "120" })
    discrepancies = PitScoutingDiscrepancyService.new([ first, second ]).discrepancies

    assert_nil discrepancies.find { |d| d[:key] == "robot_weight" }
  end

  test "differing numerics flag a discrepancy" do
    first = build_entry(data: { "robot_weight" => 118 })
    second = build_entry(data: { "robot_weight" => 120 })
    discrepancies = PitScoutingDiscrepancyService.new([ first, second ]).discrepancies

    weight = discrepancies.find { |d| d[:key] == "robot_weight" }
    assert_not_nil weight
  end

  # --- Array fields ---

  test "array order does not count as disagreement" do
    first = build_entry(data: { "intake_types" => [ "over_bumper", "through_bumper" ] })
    second = build_entry(data: { "intake_types" => [ "through_bumper", "over_bumper" ] })
    discrepancies = PitScoutingDiscrepancyService.new([ first, second ]).discrepancies

    assert_nil discrepancies.find { |d| d[:key] == "intake_types" }
  end

  test "differing arrays flag a discrepancy" do
    first = build_entry(data: { "intake_types" => [ "over_bumper" ] })
    second = build_entry(data: { "intake_types" => [ "over_bumper", "through_bumper" ] })
    discrepancies = PitScoutingDiscrepancyService.new([ first, second ]).discrepancies

    assert_not_nil discrepancies.find { |d| d[:key] == "intake_types" }
  end

  test "nil and empty array agree" do
    first = build_entry(data: {})
    second = build_entry(data: { "shooter_types" => [] })
    discrepancies = PitScoutingDiscrepancyService.new([ first, second ]).discrepancies

    assert_nil discrepancies.find { |d| d[:key] == "shooter_types" }
  end

  # --- Excluded fields ---

  test "free-text differences are ignored" do
    first = build_entry(data: { "strengths" => "Fast cycles", "weaknesses" => "Tips over" })
    second = build_entry(data: { "strengths" => "Great defense", "weaknesses" => "Slow" })
    discrepancies = PitScoutingDiscrepancyService.new([ first, second ]).discrepancies

    assert_empty discrepancies
  end

  # --- Status handling ---

  test "rejected entries are excluded" do
    rejected = build_entry(data: { "drivetrain" => "Tank" }, status: :rejected)
    discrepancies = PitScoutingDiscrepancyService.new([ pit_scouting_entries(:pit_254), rejected ]).discrepancies

    assert_empty discrepancies
  end

  test "Other mechanism compares by display text" do
    first = build_entry(data: { "intake_mechanism" => "Other", "intake_mechanism_other" => "Custom arm" })
    second = build_entry(data: { "intake_mechanism" => "Other", "intake_mechanism_other" => "Custom arm" })
    discrepancies = PitScoutingDiscrepancyService.new([ first, second ]).discrepancies

    assert_nil discrepancies.find { |d| d[:key] == "intake_mechanism_display" }
  end

  private

  def build_entry(data:, status: :submitted)
    PitScoutingEntry.new(
      user: users(:admin_user),
      event: @event,
      frc_team: @team,
      data: data,
      status: status
    )
  end
end
