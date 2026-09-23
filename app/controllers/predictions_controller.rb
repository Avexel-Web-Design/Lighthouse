class PredictionsController < ApplicationController
  before_action :require_event!
  skip_after_action :pundit_verify

  def index
    authorize :prediction, :index?

    @matches = current_event.matches.ordered.includes(:frc_teams, :match_alliances)
    @predictions = Prediction.where(event: current_event)
                             .where(source: "blended")
                             .index_by(&:match_id)

    # Calculate accuracy for completed predictions
    completed = Prediction.where(event: current_event)
                          .where.not(actual_red_score: nil)
    @accuracy = if completed.any?
      correct = completed.count(&:correct?)
      (correct.to_f / completed.count * 100).round(1)
    end
  end

  def show
    authorize :prediction, :show?

    @match = current_event.matches.includes(match_alliances: :frc_team).find(params[:id])
    @prediction = Prediction.find_by(match: @match, event: current_event, source: "blended")

    red_alliances = @match.match_alliances.select { |ma| ma.alliance_color == "red" }
    blue_alliances = @match.match_alliances.select { |ma| ma.alliance_color == "blue" }

    @red_teams = red_alliances.sort_by(&:station).map(&:frc_team)
    @blue_teams = blue_alliances.sort_by(&:station).map(&:frc_team)

    summaries_by_team = TeamEventSummary.where(event: current_event, frc_team_id: (@red_teams + @blue_teams).map(&:id))
                                        .includes(:frc_team)
                                        .index_by(&:frc_team_id)
    @red_summaries = @red_teams.filter_map { |t| summaries_by_team[t.id] }
    @blue_summaries = @blue_teams.filter_map { |t| summaries_by_team[t.id] }
  end

  def generate
    authorize :prediction, :generate?

    # Warm Statbotics cache first, then generate predictions
    SyncStatboticsJob.perform_later(current_event.id)

    service = PredictionService.new(current_event)
    count = service.generate_all!

    redirect_to predictions_path, notice: "Generated predictions for #{count} matches."
  rescue StandardError => e
    Rails.logger.warn("[PredictionsController] Generate failed for event #{current_event&.id}: #{e.class}: #{e.message}")
    redirect_to predictions_path, alert: "Failed to generate predictions. Please try again later."
  end
end
