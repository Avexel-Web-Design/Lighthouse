# frozen_string_literal: true

require "test_helper"

class AggregationServiceTest < ActiveSupport::TestCase
  setup do
    @event = events(:championship)
    scouting_entries(:entry_qm4_254_live).destroy!
    @service = AggregationService.new(@event)
  end

  # -- aggregate_team --

  test "aggregate_team returns correct structure" do
    agg = @service.aggregate_team(frc_teams(:team_254))

    expected_keys = %i[
      frc_team avg_fuel_made avg_fuel_missed fuel_accuracy_pct
      avg_climb_points avg_total_points stddev_total_points
      matches_scouted confidence scouting_entries
    ]

    expected_keys.each do |key|
      assert agg.key?(key), "Expected key #{key} in aggregation result"
    end
  end

  test "aggregate_team returns correct values for team_254" do
    agg = @service.aggregate_team(frc_teams(:team_254))

    # Entry 1: fuel_made = 5+12+0 = 17, fuel_missed = 1+3+0 = 4
    # Entry 2: fuel_made = 6+14+0 = 20, fuel_missed = 0+2+0 = 2
    # (entry_qm4_254_live is removed in setup so team 254 has exactly these 2)
    assert_equal 2, agg[:matches_scouted]
    assert_in_delta 18.5, agg[:avg_fuel_made], 0.01   # (17+20)/2
    assert_in_delta 3.0,  agg[:avg_fuel_missed], 0.01 # (4+2)/2

    # Fuel accuracy: (17+20) / (17+20+4+2) = 37/43 * 100 ~ 86.0
    assert_in_delta 86.0, agg[:fuel_accuracy_pct], 0.1

    # Climb: both entries have auton_climb=true (15) + L3 (30) = 45 each
    assert_in_delta 45.0, agg[:avg_climb_points], 0.01

    # Total points per entry:
    #   Entry 1: 17*1 + 15 + 30 = 62
    #   Entry 2: 20*1 + 15 + 30 = 65
    #   Avg: (62+65)/2 = 63.5
    assert_in_delta 63.5, agg[:avg_total_points], 0.01

    # stddev of [62, 65]: sqrt(((62-63.5)^2 + (65-63.5)^2) / 1) = sqrt(4.5) ~ 2.12
    assert_in_delta 2.12, agg[:stddev_total_points], 0.01
  end

  test "aggregate_team returns correct values for team_1678" do
    agg = @service.aggregate_team(frc_teams(:team_1678))

    # Entry 1 (qm1_1678, lead_user): fuel_made = 3+10+0 = 13, auton_climb=false (0), L2 (20) => 13 + 0 + 20 = 33
    # Entry 2 (qm2_1678, admin_user): fuel_made = 4+11+0 = 15, auton_climb=true (15), L2 (20) => 15 + 15 + 20 = 50
    # Entry 3 (qm1_1678_owner, owner_user): fuel_made = 3+10+0 = 13, auton_climb=false (0), L2 (20) => 13 + 0 + 20 = 33
    assert_equal 3, agg[:matches_scouted]
    assert_in_delta 38.67, agg[:avg_total_points], 0.01 # (33+50+33)/3
  end

  test "aggregate_team returns correct values for team_4414" do
    agg = @service.aggregate_team(frc_teams(:team_4414))

    # Entry 1 (qm1_4414): fuel_made = 4+8+0 = 12, auton_climb=false (0), L2 (20) => 12 + 0 + 20 = 32
    assert_equal 1, agg[:matches_scouted]
    assert_in_delta 32.0, agg[:avg_total_points], 0.01
  end

  test "aggregate_team confidence is low for fewer than 3 entries" do
    agg = @service.aggregate_team(frc_teams(:team_254))
    assert_equal "low", agg[:confidence] # 2 entries => low (0...3)
  end

  # -- aggregate_all_teams --

  test "aggregate_all_teams returns all scouted teams sorted by avg_total_points desc" do
    results = @service.aggregate_all_teams

    team_numbers = results.map { |agg| agg[:frc_team].team_number }

    # All five teams with scouting entries should appear
    assert_includes team_numbers, 254
    assert_includes team_numbers, 1678
    assert_includes team_numbers, 4414
    assert_includes team_numbers, 118
    assert_includes team_numbers, 971

    # 254 has highest avg total points, so should be first
    assert_equal 254, results.first[:frc_team].team_number
  end

  test "aggregate_all_teams excludes non-submitted entries" do
    # Reject one entry and verify it's excluded
    entry = scouting_entries(:entry_qm1_254)
    entry.update!(status: :flagged)

    results = @service.aggregate_all_teams
    agg_254 = results.find { |a| a[:frc_team].team_number == 254 }

    assert_equal 1, agg_254[:matches_scouted]
  end

  # -- detect_conflicts! --

  test "detect_conflicts! returns empty array when no duplicates exist" do
    conflicts = @service.detect_conflicts!
    assert_equal [], conflicts
  end

  test "detect_conflicts! detects conflicting scouting data for same team+match" do
    # Create a second entry for team_254 in qm1 with different data from a different scout
    ScoutingEntry.create!(
      user: users(:lead_user),
      match: matches(:qm1),
      frc_team: frc_teams(:team_254),
      event: @event,
      data: {
        "auton_fuel_made" => 10, # was 5 in original — 66% relative diff
        "auton_fuel_missed" => 1,
        "teleop_fuel_made" => 12,
        "teleop_fuel_missed" => 3,
        "endgame_fuel_made" => 0,
        "endgame_fuel_missed" => 0,
        "endgame_climb" => "L3",
        "auton_climb" => true
      },
      notes: "Conflicting scout data",
      status: :submitted,
      client_uuid: "conflict-uuid-001"
    )

    conflicts = @service.detect_conflicts!
    assert conflicts.any?, "Expected at least one conflict to be detected"

    conflict = conflicts.find { |c| c.field_name == "auton_fuel_made" }
    assert_not_nil conflict
    assert_equal false, conflict.resolved
  end
end
