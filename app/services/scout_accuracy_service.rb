class ScoutAccuracyService
  def initialize(event)
    @event = event
  end

  # Returns an array of hashes sorted by accuracy (most accurate first).
  # Scouts with 0 scored matches appear at the bottom sorted by entry count descending.
  #
  # Each hash:
  #   { user:, average_error:, scored_match_count:, total_entry_count: }
  def call
    scored_results = compute_accuracy
    entry_counts = total_entry_counts

    # Build results for scouts with scored matches
    with_accuracy = scored_results.map do |user_id, data|
      {
        user_id: user_id,
        average_error: (data[:total_error].to_f / data[:match_count]).round(1),
        scored_match_count: data[:match_count],
        total_entry_count: entry_counts[user_id] || 0
      }
    end

    # Build results for scouts with entries but no scored matches
    without_accuracy = entry_counts
      .reject { |user_id, _| scored_results.key?(user_id) }
      .map do |user_id, count|
        {
          user_id: user_id,
          average_error: nil,
          scored_match_count: 0,
          total_entry_count: count
        }
      end

    # Sort: scored scouts by average_error ascending, then unscored by entry count descending
    sorted_with = with_accuracy.sort_by { |r| r[:average_error] }
    sorted_without = without_accuracy.sort_by { |r| -r[:total_entry_count] }

    # Load users and attach
    all_user_ids = (sorted_with + sorted_without).map { |r| r[:user_id] }
    users_by_id = User.where(id: all_user_ids).index_by(&:id)

    (sorted_with + sorted_without).map do |result|
      result.merge(user: users_by_id[result[:user_id]])
    end
  end

  private

  # Returns a hash: { user_id => { total_error:, match_count: } }
  #
  # Uses every counted entry on scored matches, including partially scouted
  # alliances. Each entry is compared against an equal-share expected score for
  # that alliance (actual alliance score divided by alliance team count).
  # Equal-share is a deliberate approximation: without per-robot breakdowns
  # in official scores, even contribution is the only neutral baseline.
  def compute_accuracy
    results = Hash.new { |h, k| h[k] = { total_error: 0.0, match_count: 0 } }

    matches_with_scores = @event.matches.with_scores.includes(
      :match_alliances, :scouting_entries
    )

    matches_with_scores.find_each do |match|
      alliances_by_color = match.match_alliances.group_by(&:alliance_color)
      entries_by_team = match.scouting_entries.group_by(&:frc_team_id)

      %w[red blue].each do |color|
        actual_score = color == "red" ? match.red_score : match.blue_score
        next unless actual_score

        team_ids = alliances_by_color.fetch(color, []).map(&:frc_team_id)
        next if team_ids.empty?

        expected_points_per_team = actual_score.to_f / team_ids.size

        # Score each counted entry independently so partial alliances count.
        team_ids.each do |team_id|
          Array(entries_by_team[team_id]).each do |entry|
            next unless entry.counted?

            entry_error = (entry.total_points - expected_points_per_team).abs

            bucket = results[entry.user_id]
            bucket[:total_error] += entry_error
            bucket[:match_count] += 1
          end
        end
      end
    end

    results
  end

  # Returns { user_id => count } for all counted entries at this event
  def total_entry_counts
    ScoutingEntry.where(event: @event).counted.group(:user_id).count
  end
end
