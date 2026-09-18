# frozen_string_literal: true

class RefreshPredictionsJob < ApplicationJob
  queue_as :default
  retry_on Faraday::Error, Timeout::Error, wait: :polynomially_longer, attempts: 3

  # Regenerates all match predictions for an event using
  # blended scouting + Statbotics EPA data.
  def perform(event_id)
    event = Event.find_by(id: event_id)
    return unless event

    service = PredictionService.new(event)
    count = service.generate_all!

    Rails.logger.info("[RefreshPredictionsJob] Generated #{count} predictions for event #{event.name}")
  end
end
