class AccuracyFlaggingService
  # Alliance totals are typically < 300 pts, so 1000 indicates gross data
  # error rather than normal scouting variance. Kept intentionally high to
  # avoid false positives.
  FLAG_THRESHOLD = 1000
  ALLIANCE_TEAM_COUNT = 3

  def initialize(event)
    @event = event
  end

  # Flags scouting entries whose alliance total deviates from the actual
  # match score by more than FLAG_THRESHOLD points. Unflags entries that
  # were previously auto-flagged but now fall within the threshold (e.g.,
  # after an entry is corrected).
  #
  # Only touches entries with `submitted` or `flagged` status; `rejected`
  # entries are never modified. Returns the number of entries whose status
  # changed.
  def call
    changed_count = 0
    to_flag = []
    to_unflag = []

    matches_with_scores = @event.matches.with_scores.includes(
      { match_alliances: :frc_team }, :scouting_entries
    )

    matches_with_scores.find_each do |match|
      alliances_by_color = match.match_alliances.group_by(&:alliance_color)

      %w[red blue].each do |color|
        actual_score = color == "red" ? match.red_score : match.blue_score
        next unless actual_score

        # Get the teams on this alliance
        team_ids = alliances_by_color.fetch(color, []).map(&:frc_team_id)
        next if team_ids.size < ALLIANCE_TEAM_COUNT

        # Find non-rejected scouting entries for all 3 teams in this match
        entries_by_team = match.scouting_entries.group_by(&:frc_team_id)
        next unless team_ids.all? { |tid| entries_by_team.key?(tid) && entries_by_team[tid].any? { |e| !e.rejected? } }

        # Average duplicates per team so a double-scouted team does not
        # dominate the alliance total; then sum the per-team averages.
        scouted_total = team_ids.sum do |tid|
          team_entries = entries_by_team[tid].reject(&:rejected?)
          team_entries.sum(&:total_points).to_f / team_entries.size
        end

        alliance_error = (scouted_total - actual_score).abs

        # Collect all alliance entries for status update
        alliance_entries = team_ids.flat_map { |tid| entries_by_team[tid].reject(&:rejected?) }

        if alliance_error > FLAG_THRESHOLD
          # Flag submitted entries that exceed the threshold
          alliance_entries.each do |entry|
            to_flag << entry.id if entry.submitted?
          end
        else
          # Unflag entries that are now within the threshold
          alliance_entries.each do |entry|
            to_unflag << entry.id if entry.flagged?
          end
        end
      end
    end

    # Batched writes: ScoutingEntry has no update callbacks (only
    # after_create broadcast), so update_all is safe and avoids N+1 updates.
    # updated_at is touched explicitly since update_all skips timestamps.
    if to_flag.any?
      changed_count += ScoutingEntry.where(id: to_flag).update_all(status: ScoutingEntry.statuses[:flagged], updated_at: Time.current)
    end
    if to_unflag.any?
      changed_count += ScoutingEntry.where(id: to_unflag).update_all(status: ScoutingEntry.statuses[:submitted], updated_at: Time.current)
    end

    Rails.logger.info("[AccuracyFlaggingService] Changed #{changed_count} entry statuses for event #{@event.name}")
    changed_count
  end
end
