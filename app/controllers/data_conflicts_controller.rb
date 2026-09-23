class DataConflictsController < ApplicationController
  before_action :require_event!

  def index
    @data_conflicts = policy_scope(DataConflict)
                        .where(event: current_event)
                        .unresolved
                        .includes(:frc_team, :match)
                        .order(created_at: :desc)
                        .to_a

    preload_conflicting_entries!
  end

  def resolve
    @data_conflict = policy_scope(DataConflict).where(event: current_event).find(params[:id])
    authorize @data_conflict

    DataConflictResolutionService.new(
      @data_conflict,
      resolution_value: params[:resolution],
      approved_entry_id: params[:approved_entry_id],
      resolved_by: current_user
    ).resolve!

    redirect_to data_conflicts_path, notice: "Conflict resolved and scouting data updated."
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to data_conflicts_path, alert: e.message
  end

  private

  # Batches conflicting_entries (one query) + scout users (one query) to avoid
  # N+1s in the view (was: one entries query per conflict + User.find_by per scout).
  def preload_conflicting_entries!
    @entries_by_conflict = {}
    @users_by_id = {}
    return if @data_conflicts.empty?

    match_ids = @data_conflicts.map(&:match_id).uniq
    team_ids = @data_conflicts.map(&:frc_team_id).uniq

    all_entries = ScoutingEntry.where(event: current_event, match_id: match_ids, frc_team_id: team_ids)
                               .where.not(status: :rejected)
                               .includes(:user, :frc_team)
                               .order(:created_at)
                               .to_a

    grouped = all_entries.group_by { |e| [ e.frc_team_id, e.match_id ] }
    @data_conflicts.each do |conflict|
      @entries_by_conflict[conflict.id] = grouped[[ conflict.frc_team_id, conflict.match_id ]] || []
    end

    scout_ids = @data_conflicts.flat_map { |c| Array(c.values&.keys).map(&:to_i) }.uniq
    scout_ids -= @entries_by_conflict.values.flatten.map(&:user_id).uniq
    @users_by_id = User.where(id: scout_ids).index_by(&:id) if scout_ids.any?
  end
end
