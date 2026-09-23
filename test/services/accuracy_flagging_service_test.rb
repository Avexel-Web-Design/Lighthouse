# frozen_string_literal: true

require "test_helper"

class AccuracyFlaggingServiceTest < ActiveSupport::TestCase
  setup do
    @event = events(:championship)
    @service = AccuracyFlaggingService.new(@event)
  end

  test "returns 0 and flags nothing when scouted totals are within threshold" do
    assert_equal 0, @service.call

    assert scouting_entries(:entry_qm1_254).reload.submitted?
    assert scouting_entries(:entry_qm1_4414).reload.submitted?
    assert scouting_entries(:entry_qm1_118).reload.submitted?
  end

  test "flags submitted entries when alliance error exceeds threshold" do
    matches(:qm1).update!(red_score: 5000)

    assert_equal 3, @service.call

    assert scouting_entries(:entry_qm1_254).reload.flagged?
    assert scouting_entries(:entry_qm1_4414).reload.flagged?
    assert scouting_entries(:entry_qm1_118).reload.flagged?
  end

  test "unflags previously flagged entries once back within threshold" do
    matches(:qm1).update!(red_score: 5000)
    @service.call

    matches(:qm1).update!(red_score: 180)

    assert_equal 3, @service.call

    assert scouting_entries(:entry_qm1_254).reload.submitted?
    assert scouting_entries(:entry_qm1_4414).reload.submitted?
    assert scouting_entries(:entry_qm1_118).reload.submitted?
  end

  test "never modifies rejected entries" do
    scouting_entries(:entry_qm1_254).update!(status: :rejected)
    matches(:qm1).update!(red_score: 5000)

    assert_equal 0, @service.call

    assert scouting_entries(:entry_qm1_254).reload.rejected?
    assert scouting_entries(:entry_qm1_4414).reload.submitted?
    assert scouting_entries(:entry_qm1_118).reload.submitted?
  end

  test "skips alliances without full 3-team scouting coverage" do
    # qm1 blue alliance only has 1 scouted team, so even a wild score is ignored
    matches(:qm1).update!(blue_score: 5000)

    assert_equal 0, @service.call
    assert scouting_entries(:entry_qm1_1678).reload.submitted?
  end

  test "skips matches without scores" do
    matches(:qm3).update!(red_score: nil, blue_score: nil)

    assert_nothing_raised { @service.call }
  end
end
