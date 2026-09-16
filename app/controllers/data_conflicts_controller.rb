class DataConflictsController < ApplicationController
  before_action :require_event!

  def index
    @data_conflicts = policy_scope(DataConflict)
                        .where(event: current_event)
                        .unresolved
                        .includes(:frc_team, :match)
                        .order(created_at: :desc)
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
end
