class ScoutingAssignmentsController < ApplicationController
  MAX_BULK_USERS = 50
  MAX_NOTES_LENGTH = 500

  before_action :require_event!
  before_action :ensure_qualification_matches!, only: :index
  before_action :set_matches, only: :index

  def index
    authorize ScoutingAssignment

    scoped_assignments = policy_scope(ScoutingAssignment)
                           .where(event: current_event)
                           .includes(:user, :match)

    if current_user.admin?
      @users = User.order(:last_name, :first_name)
      @assignments = scoped_assignments
    else
      @users = [ current_user ]
      @assignments = scoped_assignments.where(user_id: current_user.id)
    end

    @assignment_lookup = @assignments.index_by { |a| [ a.user_id, a.match_id ] }
    @coverage_counts = policy_scope(ScoutingAssignment).where(event: current_event, match_id: @matches.map(&:id)).group(:match_id).count
    @match_position = @matches.each_with_index.to_h
    @current_match_index = latest_completed_match_index(@matches) || 0
    @shift_starts = compute_shift_starts(@assignments)
    @is_admin = current_user.admin?

    unless @is_admin
      @shift_blocks = compute_shift_blocks(@assignments)
    end
  end

  def toggle
    authorize ScoutingAssignment, :toggle?

    toggle_ids = params.permit(:user_id, :match_id)
    @user = User.find(toggle_ids[:user_id].to_i)
    @match = current_event.matches.find(toggle_ids[:match_id].to_i)

    @assignment = ScoutingAssignment.find_by(event: current_event, user: @user, match: @match)

    if @assignment
      @assignment.destroy
      unless @assignment.destroyed?
        respond_to do |format|
          format.turbo_stream { head :unprocessable_entity }
          format.html { redirect_to scouting_assignments_path, alert: "Could not remove assignment." }
        end
        return
      end
      @assignment = nil
    else
      @assignment = ScoutingAssignment.create(event: current_event, user: @user, match: @match)
      unless @assignment.persisted?
        respond_to do |format|
          format.turbo_stream { head :unprocessable_entity }
          format.html { redirect_to scouting_assignments_path, alert: "Could not save assignment." }
        end
        return
      end
    end

    @coverage_count = policy_scope(ScoutingAssignment).where(event: current_event, match: @match).count
    @is_shift_start = shift_start?(@user, @match)
    @is_admin = true

    # The next cell's shift-start status may have changed
    @next_match = current_event.matches.find_by(comp_level: "qm", match_number: @match.match_number + 1)
    if @next_match
      @next_assignment = ScoutingAssignment.find_by(event: current_event, user: @user, match: @next_match)
      @next_is_shift_start = @next_assignment ? shift_start?(@user, @next_match) : false
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to scouting_assignments_path, notice: "Assignment updated." }
    end
  end

  def bulk_create
    authorize ScoutingAssignment, :bulk_create?
    current_event.ensure_qualification_matches!

    range = assignment_range
    if range.nil?
      redirect_to scouting_assignments_path, alert: "Provide a valid match range."
      return
    end

    created = ScoutingAssignments::BulkAssignService.new(
      event: current_event,
      user_ids: bulk_params[:user_ids],
      start_match_number: range.first,
      end_match_number: range.last,
      notes: bulk_params[:notes]
    ).call

    redirect_to scouting_assignments_path,
                notice: "Saved #{created} assignment#{"s" unless created == 1}."
  rescue StandardError => e
    Rails.logger.warn("[ScoutingAssignmentsController] Bulk create failed: #{e.class}: #{e.message}")
    redirect_to scouting_assignments_path, alert: "Failed to save assignments. Please try again."
  end

  def bulk_destroy
    authorize ScoutingAssignment, :bulk_destroy?
    current_event.ensure_qualification_matches!

    range = assignment_range
    if range.nil?
      redirect_to scouting_assignments_path, alert: "Provide a valid match range."
      return
    end

    removed = ScoutingAssignments::BulkClearService.new(
      event: current_event,
      user_ids: bulk_params[:user_ids],
      start_match_number: range.first,
      end_match_number: range.last
    ).call

    redirect_to scouting_assignments_path,
                notice: "Cleared #{removed} assignment#{"s" unless removed == 1}."
  rescue StandardError => e
    Rails.logger.warn("[ScoutingAssignmentsController] Bulk destroy failed: #{e.class}: #{e.message}")
    redirect_to scouting_assignments_path, alert: "Failed to clear assignments. Please try again."
  end

  def destroy
    assignment = ScoutingAssignment.where(event: current_event).find(params[:id])
    authorize assignment

    assignment.destroy
    if assignment.destroyed?
      redirect_to scouting_assignments_path, notice: "Assignment removed.", status: :see_other
    else
      redirect_to scouting_assignments_path, alert: "Could not remove assignment."
    end
  end

  private

  def set_matches
    @matches = current_event.matches
                           .where(comp_level: "qm", match_number: 1..Event::QUALIFICATION_MATCH_COUNT)
                           .ordered
  end

  def ensure_qualification_matches!
    current_event.ensure_qualification_matches!
  end

  def bulk_params
    allowed = params.permit(:start_match_number, :end_match_number, :match_count, :notes, user_ids: [])
    allowed[:user_ids] = Array(allowed[:user_ids]).map(&:to_i).select(&:positive?).uniq.first(MAX_BULK_USERS)
    allowed[:notes] = allowed[:notes].to_s.strip.first(MAX_NOTES_LENGTH)
    allowed
  end

  def assignment_range
    max_match = Event::QUALIFICATION_MATCH_COUNT
    start_match = bulk_params[:start_match_number].to_i
    return nil unless start_match.between?(1, max_match)

    if bulk_params[:end_match_number].present?
      end_match = bulk_params[:end_match_number].to_i
    elsif bulk_params[:match_count].present?
      count = bulk_params[:match_count].to_i
      return nil unless count.between?(1, max_match)

      end_match = start_match + count - 1
    else
      end_match = start_match
    end

    return nil unless end_match.between?(1, max_match)

    lower, upper = [ start_match, end_match ].minmax
    return nil if (upper - lower + 1) > max_match

    [ lower, upper ]
  end

  def latest_completed_match_index(matches)
    matches.rindex { |match| match.red_score.present? && match.blue_score.present? }
  end

  # Returns a Set of [user_id, match_id] pairs that are the first match in a
  # contiguous block of assignments (i.e. "shift starts").
  def compute_shift_starts(assignments)
    starts = Set.new

    assignments.group_by(&:user_id).each do |user_id, user_assignments|
      sorted = user_assignments.sort_by { |a| a.match.match_number }
      sorted.each_with_index do |a, i|
        if i == 0 || a.match.match_number != sorted[i - 1].match.match_number + 1
          starts.add([ user_id, a.match_id ])
        end
      end
    end

    starts
  end

  # Returns an array of shift block hashes for a user's assignments.
  # Each hash has :start_match, :end_match, :match_count, :notes, and :status.
  def compute_shift_blocks(assignments)
    sorted = assignments.sort_by { |a| a.match.match_number }
    return [] if sorted.empty?

    blocks = []
    block_start = sorted.first
    block_end = sorted.first

    sorted.drop(1).each do |a|
      if a.match.match_number == block_end.match.match_number + 1
        block_end = a
      else
        blocks << build_shift_block(block_start, block_end, sorted)
        block_start = a
        block_end = a
      end
    end
    blocks << build_shift_block(block_start, block_end, sorted)

    # Determine status for each block
    blocks.each do |block|
      block[:status] = shift_block_status(block)
    end

    blocks
  end

  def build_shift_block(block_start, block_end, sorted)
    match_count = block_end.match.match_number - block_start.match.match_number + 1
    {
      start_match: block_start.match,
      end_match: block_end.match,
      match_count: match_count,
      notes: block_start.notes
    }
  end

  def shift_block_status(block)
    start_match = block[:start_match]
    end_match = block[:end_match]

    if end_match.red_score.present? && end_match.blue_score.present?
      :completed
    elsif start_match.red_score.present? && start_match.blue_score.present?
      :active
    else
      :upcoming
    end
  end

  # Checks whether a specific user+match assignment is a shift start by
  # looking at the previous match number.
  def shift_start?(user, match)
    return false unless ScoutingAssignment.exists?(event: current_event, user: user, match: match)

    prev_match = current_event.matches.find_by(comp_level: "qm", match_number: match.match_number - 1)
    return true if prev_match.nil?

    !ScoutingAssignment.exists?(event: current_event, user: user, match: prev_match)
  end
end
