require "test_helper"

class PickListTest < ActiveSupport::TestCase
  # --- Validations ---

  test "team lookups reflect event membership changes on the same instance" do
    pick_list = pick_lists(:championship_picks)
    team = frc_teams(:team_254)
    membership = EventTeam.find_by!(event: pick_list.event, frc_team: team)
    assert_includes pick_list.ordered_team_ids, team.id

    membership.destroy!
    assert_not_includes pick_list.ordered_team_ids, team.id

    EventTeam.create!(event: pick_list.event, frc_team: team)
    assert_includes pick_list.ordered_team_ids, team.id
  end

  test "valid pick list from fixtures" do
    assert pick_lists(:championship_picks).valid?
  end

  test "invalid entries stay invalid across validation attempts" do
    pick_list = pick_lists(:championship_picks)
    pick_list.entries = [ frc_teams(:team_6328).id ]

    2.times { assert_not pick_list.valid? }
    assert_equal [ frc_teams(:team_6328).id ], pick_list.entries
    assert_not pick_list.save
  end

  test "ordered team ids reflect in place edits reloads and event changes" do
    pick_list = pick_lists(:championship_picks)
    pick_list.entries = [ frc_teams(:team_254).id ]
    assert_equal [ frc_teams(:team_254).id ], pick_list.ordered_team_ids
    pick_list.entries << frc_teams(:team_1678).id
    assert_equal [ frc_teams(:team_254).id, frc_teams(:team_1678).id ], pick_list.ordered_team_ids
    pick_list.save!
    PickList.where(id: pick_list.id).update_all(entries: [ frc_teams(:team_118).id ])
    assert_equal [ frc_teams(:team_118).id ], pick_list.reload.ordered_team_ids
    pick_list.event = Event.create!(name: "Empty event", year: 2026)
    assert_empty pick_list.ordered_team_ids
    assert_not pick_list.valid?
  end

  test "requires name" do
    pick_list = pick_lists(:championship_picks)
    pick_list.name = nil
    assert_not pick_list.valid?
    assert_includes pick_list.errors[:name], "can't be blank"
  end

  # --- Associations ---

  test "belongs to event" do
    assert_equal events(:championship), pick_lists(:championship_picks).event
  end

  test "belongs to user" do
    assert_equal users(:admin_user), pick_lists(:championship_picks).user
  end

  # --- Fixture data ---

  test "championship_picks has correct name" do
    assert_equal "Championship Pick List", pick_lists(:championship_picks).name
  end

  test "normalizes hash entries into ordered team ids" do
    pick_list = PickList.create!(
      name: "Test Picks",
      entries: [
        { "rank" => 1, "team_number" => 254, "notes" => "Top pick" },
        { "rank" => 2, "team_number" => 1678, "notes" => "Strong second" }
      ],
      event: events(:championship),
      user: users(:admin_user)
    )

    assert_equal [ frc_teams(:team_254).id, frc_teams(:team_1678).id ], pick_list.reload.entries
  end

  test "preserves fixture-style team numbers as event team ids" do
    pick_list = pick_lists(:championship_picks)

    assert_equal [
      frc_teams(:team_254).id,
      frc_teams(:team_1678).id,
      frc_teams(:team_118).id,
      frc_teams(:team_4414).id
    ], pick_list.ordered_team_ids
  end

  test "rejects teams that are not at the event" do
    pick_list = PickList.new(
      name: "Invalid Picks",
      entries: [ frc_teams(:team_6328).id ],
      event: events(:championship),
      user: users(:admin_user)
    )

    2.times { assert_not pick_list.valid? }
    assert_equal [ frc_teams(:team_6328).id ], pick_list.entries
    assert_not pick_list.save
    assert_includes pick_list.errors[:entries], "contain teams that are not part of the selected event"
  end
end
