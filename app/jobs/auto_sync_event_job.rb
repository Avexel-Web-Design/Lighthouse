# frozen_string_literal: true

class AutoSyncEventJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 2

  # Runs TBA sync and downstream jobs asynchronously after dashboard load.
  # Downstream jobs are only enqueued after a successful TBA sync (or when
  # no TBA sync is needed). A raised sync error re-raises so the job retries
  # instead of fanning out on stale data.
  def perform(event_id)
    event = Event.find_by(id: event_id)
    return unless event

    if event.tba_key.present? && TbaClient.configured?
      begin
        TbaSyncService.new(event.tba_key).sync_matches!
      rescue StandardError => e
        Rails.logger.error("[AutoSyncEventJob] TBA sync failed for event #{event.tba_key}: #{e.message}; skipping downstream")
        raise
      end
    end

    RefreshSummariesJob.perform_later(event.id)
    SyncStatboticsJob.perform_later(event.id)
    RefreshPredictionsJob.perform_later(event.id)

    Rails.logger.info("[AutoSyncEventJob] Enqueued downstream sync for event #{event.tba_key}")
  end
end
