# frozen_string_literal: true

require "test_helper"

class RefreshSummariesJobTest < ActiveJob::TestCase
  setup do
    @event = events(:championship)
  end

  test "refreshes the materialized view" do
    RefreshSummariesJob.perform_now(@event.id)

    summary = TeamEventSummary.find_by(event: @event, frc_team: frc_teams(:team_254))
    assert_not_nil summary
    assert_operator summary.matches_scouted, :>=, 2
  end

  test "returns without error for an unknown event id" do
    assert_nothing_raised { RefreshSummariesJob.perform_now(-1) }
  end

  test "can be enqueued with an event id" do
    assert_enqueued_with(job: RefreshSummariesJob, args: [ @event.id ]) do
      RefreshSummariesJob.perform_later(@event.id)
    end
  end

  test "detects new conflicts by default" do
    DataConflict.where(event: @event).delete_all
    create_disagreeing_entry!

    assert_changes("DataConflict.count", from: 0) do
      RefreshSummariesJob.perform_now(@event.id)
    end

    assert DataConflict.where(
      event: @event,
      frc_team: frc_teams(:team_254),
      match: matches(:qm1),
      field_name: "endgame_climb"
    ).exists?
  end

  test "skips conflict detection when detect_conflicts is false" do
    create_disagreeing_entry!

    assert_no_difference("DataConflict.count") do
      RefreshSummariesJob.perform_now(@event.id, detect_conflicts: false)
    end
  end

  private

  def create_disagreeing_entry!
    ScoutingEntry.create!(
      user: users(:scout_user),
      match: matches(:qm1),
      frc_team: frc_teams(:team_254),
      event: @event,
      data: {
        "auton_fuel_made" => 1,
        "auton_fuel_missed" => 5,
        "teleop_fuel_made" => 2,
        "teleop_fuel_missed" => 8,
        "endgame_fuel_made" => 0,
        "endgame_fuel_missed" => 0,
        "endgame_climb" => "L1",
        "auton_climb" => false,
        "defense_rating" => 1
      },
      status: :submitted,
      client_uuid: "refresh-job-conflict-uuid-1"
    )
  end
end
