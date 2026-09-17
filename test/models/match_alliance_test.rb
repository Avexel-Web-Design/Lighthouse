require "test_helper"

class MatchAllianceTest < ActiveSupport::TestCase
  # --- Validations ---

  test "valid match alliance from fixtures" do
    assert match_alliances(:qm1_red_1).valid?
    assert match_alliances(:qm1_blue_1).valid?
  end

  test "requires alliance_color" do
    alliance = MatchAlliance.new(
      match: matches(:qm1),
      frc_team: frc_teams(:team_254),
      station: 1
    )
    alliance.alliance_color = nil
    assert_not alliance.valid?
    assert_includes alliance.errors[:alliance_color], "can't be blank"
  end

  test "requires station" do
    alliance = MatchAlliance.new(
      match: matches(:qm1),
      frc_team: frc_teams(:team_254),
      alliance_color: "red"
    )
    alliance.station = nil
    assert_not alliance.valid?
    assert_includes alliance.errors[:station], "can't be blank"
  end

  test "requires unique match and frc_team combination" do
    duplicate = MatchAlliance.new(
      match: matches(:qm1),
      frc_team: frc_teams(:team_254),
      alliance_color: "red",
      station: 1
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:match_id], "has already been taken"
  end

  test "same team can be in different matches" do
    # team_6328 is in qm2/qm3/qm4 but not qm1, so qm1+6328 is a valid new combo
    alliance = MatchAlliance.new(
      match: matches(:qm1),
      frc_team: frc_teams(:team_6328),
      alliance_color: "blue",
      station: 2
    )
    assert alliance.valid?, alliance.errors.full_messages.to_sentence
  end

  # --- Associations ---

  test "belongs to match" do
    alliance = match_alliances(:qm1_red_1)
    assert_equal matches(:qm1), alliance.match
  end

  test "belongs to frc_team" do
    alliance = match_alliances(:qm1_red_1)
    assert_equal frc_teams(:team_254), alliance.frc_team
  end

  # --- Fixture data verification ---

  test "qm1 red alliance has 254, 4414, 118" do
    qm1_red = MatchAlliance.where(match: matches(:qm1), alliance_color: "red")
    team_numbers = qm1_red.map { |a| a.frc_team.team_number }.sort
    assert_equal [ 118, 254, 4414 ], team_numbers
  end

  test "qm1 blue alliance has 1678" do
    qm1_blue = MatchAlliance.where(match: matches(:qm1), alliance_color: "blue")
    team_numbers = qm1_blue.map { |a| a.frc_team.team_number }
    assert_includes team_numbers, 1678
  end
end
