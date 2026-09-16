class ScoutingAssignmentNotificationJob < ApplicationJob
  queue_as :default

  THRESHOLDS = [ 5, 2, 1 ].freeze

  def perform(event_id)
    event = Event.find_by(id: event_id)
    return unless event

    ordered_matches = event.matches.where(comp_level: "qm").ordered.to_a
    return if ordered_matches.empty?

    match_index_by_id = ordered_matches.each_with_index.to_h { |match, idx| [ match.id, idx ] }
    current_index = latest_completed_match_index(ordered_matches)
    return if current_index.nil?

    # Lightweight pluck for shift-start detection (avoids loading full
    # assignment records twice: once for grouping, once for delivery).
    shift_start_ids = compute_shift_start_ids(event.id)

    ScoutingAssignment.includes(:match, :user).where(event_id: event.id).find_each do |assignment|
      # Only notify for the first match in each contiguous shift
      next unless shift_start_ids.include?(assignment.id)

      target_index = match_index_by_id[assignment.match_id]
      next if target_index.nil?

      ahead = target_index - current_index
      next unless THRESHOLDS.include?(ahead)

      notified_column = "notified_#{ahead}_at"
      next if assignment.public_send(notified_column).present?

      delivered = PushNotificationService.new(assignment.user).send_assignment_notification!(
        assignment: assignment,
        matches_ahead: ahead
      )
      next unless delivered

      # Idempotent claim: only the first writer wins. A concurrent run that
      # already marked this threshold affects 0 rows and is treated as done.
      ScoutingAssignment.where(id: assignment.id, notified_column => nil)
                        .update_all(notified_column => Time.current)
    end
  end

  private

  # Returns nil when no match has completed yet (avoids treating index 0 as
  # "completed" and sending false 5/2/1-ahead alerts before the event starts).
  def latest_completed_match_index(ordered_matches)
    ordered_matches.rindex { |match| match.red_score.present? && match.blue_score.present? }
  end

  # Returns a Set of assignment IDs that are the first match in a contiguous
  # block of assignments for each user (i.e. "shift starts").
  def compute_shift_start_ids(event_id)
    rows = ScoutingAssignment.joins(:match)
                             .where(event_id: event_id)
                             .pluck(:id, :user_id, "matches.match_number")

    shift_start_ids = Set.new

    rows.group_by { |(_id, user_id, _num)| user_id }.each_value do |user_rows|
      sorted = user_rows.sort_by { |(_id, _user, num)| num }
      sorted.each_with_index do |(id, _user, num), i|
        if i == 0 || num != sorted[i - 1][2] + 1
          shift_start_ids.add(id)
        end
      end
    end

    shift_start_ids
  end
end
