class DashboardController < ApplicationController
  skip_after_action :pundit_verify

  def index
    authorize :dashboard, :index?

    unless current_event
      redirect_to events_path and return
    end

    @event = current_event
    @team_summaries = TeamEventSummary.where(event: @event).order(avg_total_points: :desc)
    @recent_entries = ScoutingEntry.where(event: @event).includes(:user, :frc_team, :match).order(created_at: :desc).limit(10)
    @unresolved_conflicts_count = DataConflict.where(event: @event).unresolved.count
    @shift_status = UserShiftStatusService.new(@event, current_user).call

    # Pit scouting progress
    @total_teams_at_event = FrcTeam.at_event(@event).count
    @pit_scouted_count = PitScoutingEntry.where(event: @event).distinct.count(:frc_team_id)

    # Flagged (inaccurate) entries grouped by match
    @flagged_entries = ScoutingEntry.where(event: @event, status: :flagged)
                                    .includes(:frc_team, :match, :user)
                                    .order(created_at: :desc)

    # Scout accuracy leaderboard
    @scout_accuracy = current_user.admin? ? ScoutAccuracyService.new(@event).call : []

    # Scoring distribution for histogram (total points per entry)
    @scoring_data = @team_summaries.pluck(:avg_total_points).map { |v| v.to_f.round(0) }

    # Predictions summary
    @predictions_count = Prediction.where(event: @event).count
  end
end
