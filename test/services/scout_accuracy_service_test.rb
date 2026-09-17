require "test_helper"

class ScoutAccuracyServiceTest < ActiveSupport::TestCase
  setup do
    @event = events(:championship)
    @service = ScoutAccuracyService.new(@event)
  end

  # --- Basic functionality ---

  test "call returns an array of results" do
    results = @service.call
    assert_kind_of Array, results
  end

  test "each result has expected keys" do
    results = @service.call
    results.each do |r|
      assert r.key?(:user_id), "Expected :user_id key"
      assert r.key?(:user), "Expected :user key"
      assert r.key?(:average_error), "Expected :average_error key"
      assert r.key?(:scored_match_count), "Expected :scored_match_count key"
      assert r.key?(:total_entry_count), "Expected :total_entry_count key"
    end
  end

  # --- Accuracy math ---
  #
  # Accuracy now evaluates each counted entry independently against an
  # equal-share expectation for that alliance:
  #   expected_points_per_team = actual_alliance_score / alliance_team_count
  #
  # This means partially scouted alliances still contribute.

  test "computes correct average error for scouts" do
    results = @service.call
    by_user = results.index_by { |r| r[:user_id] }

    assert_equal 3.3, by_user[users(:admin_user).id][:average_error]
    assert_equal 36.7, by_user[users(:lead_user).id][:average_error]
    assert_equal 16.3, by_user[users(:scout_user).id][:average_error]
    assert_equal 57.5, by_user[users(:owner_user).id][:average_error]
  end

  test "computes correct scored match count" do
    results = @service.call
    by_user = results.index_by { |r| r[:user_id] }

    assert_equal 3, by_user[users(:admin_user).id][:scored_match_count]
    assert_equal 3, by_user[users(:lead_user).id][:scored_match_count]
    assert_equal 2, by_user[users(:scout_user).id][:scored_match_count]
    assert_equal 2, by_user[users(:owner_user).id][:scored_match_count]
  end

  test "computes correct total entry count" do
    results = @service.call
    by_user = results.index_by { |r| r[:user_id] }

    assert_equal 3, by_user[users(:admin_user).id][:total_entry_count]
    assert_equal 2, by_user[users(:scout_user).id][:total_entry_count]
    assert_equal 3, by_user[users(:lead_user).id][:total_entry_count]
    assert_equal 2, by_user[users(:owner_user).id][:total_entry_count]
  end

  # --- Sorting ---

  test "results are sorted by average error ascending" do
    results = @service.call
    errors = results.filter_map { |r| r[:average_error] }

    errors.each_cons(2) do |a, b|
      assert a <= b, "Expected #{a} <= #{b} — scored scouts should be sorted by error ascending"
    end
  end

  test "admin_user is first with lowest error" do
    results = @service.call
    assert_equal users(:admin_user).id, results.first[:user_id]
    assert_equal 3.3, results.first[:average_error]
  end

  test "scouts with accuracy appear before scouts without" do
    # Remove scores from all matches to create scouts without accuracy data
    Match.update_all(red_score: nil, blue_score: nil)

    # Add back score for qm1 only
    matches(:qm1).update!(red_score: 180, blue_score: 120)

    results = @service.call
    scored_indices = results.each_with_index
      .select { |r, _| r[:average_error].present? }
      .map(&:last)
    unscored_indices = results.each_with_index
      .select { |r, _| r[:average_error].nil? }
      .map(&:last)

    if scored_indices.any? && unscored_indices.any?
      assert scored_indices.max < unscored_indices.min,
        "All scored scouts should appear before unscored scouts"
    end
  end

  # --- Edge cases ---

  test "returns empty array for event with no entries" do
    empty_event = Event.create!(
      name: "Empty Event",
      tba_key: "2026empty",
      start_date: "2026-05-01",
      end_date: "2026-05-03",
      year: 2026
    )
    results = ScoutAccuracyService.new(empty_event).call
    assert_equal [], results
  end

  test "skips matches without scores" do
    # Remove scores from qm2 to make it unscored
    match = matches(:qm2)
    match.update!(red_score: nil, blue_score: nil)

    results = @service.call
    by_user = results.index_by { |r| r[:user_id] }

    assert_equal 2, by_user[users(:admin_user).id][:scored_match_count]
    assert_equal 5.0, by_user[users(:admin_user).id][:average_error]

    assert_equal 2, by_user[users(:lead_user).id][:scored_match_count]
    assert_equal 55.0, by_user[users(:lead_user).id][:average_error]

    assert_equal 2, by_user[users(:owner_user).id][:scored_match_count]
    assert_equal 57.5, by_user[users(:owner_user).id][:average_error]

    assert_equal 0, by_user[users(:scout_user).id][:scored_match_count]
    assert_nil by_user[users(:scout_user).id][:average_error]
  end

  test "includes partially scouted alliances" do
    results = @service.call
    total_scored = results.sum { |r| r[:scored_match_count] }

    # All counted entries on scored matches should contribute.
    assert_equal 10, total_scored
  end

  test "unscored scouts appear at bottom with nil accuracy" do
    # Remove all match scores so no one has accuracy
    Match.update_all(red_score: nil, blue_score: nil)

    # Re-add score for qm1 only
    matches(:qm1).update!(red_score: 180, blue_score: 120)

    results = @service.call
    # scout_user has entries only for qm2, so should have no scored matches
    scout_result = results.find { |r| r[:user_id] == users(:scout_user).id }

    assert_not_nil scout_result
    assert_nil scout_result[:average_error]
    assert_equal 0, scout_result[:scored_match_count]
  end

  test "approved entries still count toward scout accuracy" do
    scouting_entries(:entry_qm2_254).update!(status: :approved)
    scouting_entries(:entry_qm2_118).update!(status: :approved)

    results = @service.call
    scout_result = results.find { |r| r[:user_id] == users(:scout_user).id }

    assert_not_nil scout_result
    assert_equal 2, scout_result[:total_entry_count]
    assert_equal 2, scout_result[:scored_match_count]
  end
end
