require "test_helper"

class EventTest < ActiveSupport::TestCase
  # --- Validations ---

  test "valid event from fixtures" do
    assert events(:championship).valid?
  end

  test "preseason event types survive integer string and symbol assignments" do
    event = events(:championship)
    [ 100, "100", :preseason ].each do |type|
      event.update!(event_type: type)
      assert_equal "preseason", event.reload.event_type
      assert_equal 100, event.event_type_before_type_cast
    end
  end

  test "requires unique tba_key" do
    duplicate = Event.new(
      name: "Duplicate",
      tba_key: "2026cmp",
      year: 2026
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:tba_key], "has already been taken"
  end

  test "allows nil tba_key" do
    event = Event.new(name: "No TBA Key", year: 2026)
    event.valid?
    assert_empty event.errors[:tba_key]
  end

  # --- Associations ---

  test "has many matches" do
    event = events(:championship)
    assert_respond_to event, :matches
    assert_includes event.matches, matches(:qm1)
    assert_includes event.matches, matches(:qm2)
  end

  test "has many event_teams" do
    event = events(:championship)
    assert_respond_to event, :event_teams
    assert_equal 4, event.event_teams.count
  end

  test "has many frc_teams through event_teams" do
    event = events(:championship)
    assert_respond_to event, :frc_teams
    assert_includes event.frc_teams, frc_teams(:team_254)
    assert_includes event.frc_teams, frc_teams(:team_1678)
  end

  test "has many scouting_entries" do
    event = events(:championship)
    assert_respond_to event, :scouting_entries
    assert_equal 10, event.scouting_entries.count
  end

  test "has many pit_scouting_entries" do
    event = events(:championship)
    assert_respond_to event, :pit_scouting_entries
    assert_equal 2, event.pit_scouting_entries.count
  end

  test "has many predictions" do
    event = events(:championship)
    assert_respond_to event, :predictions
    assert_includes event.predictions, predictions(:prediction_qm1)
  end

  test "has many simulation_results" do
    event = events(:championship)
    assert_respond_to event, :simulation_results
    assert_includes event.simulation_results, simulation_results(:sim_254_vs_1678)
  end

  # --- Scopes ---

  test "current_year returns events for the current year" do
    # Championship fixture is year 2026
    travel_to Date.new(2026, 6, 1) do
      assert_includes Event.current_year, events(:championship)
    end
  end

  test "current_year excludes events from other years" do
    travel_to Date.new(2025, 6, 1) do
      assert_not_includes Event.current_year, events(:championship)
    end
  end

  test "active returns events happening today" do
    # Championship: 2026-04-15 to 2026-04-19
    travel_to Date.new(2026, 4, 17) do
      assert_includes Event.active, events(:championship)
    end
  end

  test "active excludes events not happening today" do
    travel_to Date.new(2026, 5, 1) do
      assert_not_includes Event.active, events(:championship)
    end
  end

  # --- Qualification schedule scaffolding ---

  test "ensure_qualification_matches! creates qm1 through qm80" do
    event = Event.create!(name: "No Sync Event", year: 2026)

    assert_difference("event.matches.where(comp_level: 'qm').count", 80) do
      event.ensure_qualification_matches!
    end

    assert_equal(
      (1..Event::QUALIFICATION_MATCH_COUNT).to_a,
      event.matches.where(comp_level: "qm").order(:match_number).pluck(:match_number)
    )
  end

  test "ensure_qualification_matches! does not duplicate existing qualification matches" do
    event = Event.create!(name: "Partial Event", year: 2026)
    event.matches.create!(comp_level: "qm", set_number: 1, match_number: 1)

    assert_difference("event.matches.where(comp_level: 'qm').count", Event::QUALIFICATION_MATCH_COUNT - 1) do
      event.ensure_qualification_matches!
    end

    assert_no_difference("event.matches.where(comp_level: 'qm').count") do
      event.ensure_qualification_matches!
    end
  end

  # --- Dependent destroy ---

  test "destroying event destroys dependent matches" do
    event = Event.create!(name: "Temp Destroy Event", tba_key: "2026destroy", year: 2026)
    match = Match.create!(event: event, comp_level: "qm", match_number: 1, set_number: 1)
    match_id = match.id
    event.destroy
    assert_nil Match.find_by(id: match_id)
  end
end
