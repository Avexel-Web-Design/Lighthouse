# frozen_string_literal: true

class RefreshSummariesJob < ApplicationJob
  queue_as :default

  # Refreshes the TeamEventSummary materialized view and optionally
  # runs conflict detection for the given event.
  #
  # NOTE: TeamEventSummary.refresh! uses REFRESH CONCURRENTLY (non-blocking
  # reads) but always rebuilds the full view — Postgres cannot refresh a
  # materialized view per-event without schema changes (e.g. per-event
  # tables or incremental refresh). Callers must use perform_later so
  # detect_conflicts!/flagging stay out of the request path.
  def perform(event_id, detect_conflicts: true)
    event = Event.find_by(id: event_id)
    return unless event

    # Refresh the materialized view
    TeamEventSummary.refresh!

    # Optionally detect new conflicts
    if detect_conflicts
      service = AggregationService.new(event)
      new_conflicts = service.detect_conflicts!
      Rails.logger.info("[RefreshSummariesJob] Found #{new_conflicts.size} new conflicts for event #{event.name}")
    end

    # Auto-flag entries with high alliance error vs actual match scores
    AccuracyFlaggingService.new(event).call

    Rails.logger.info("[RefreshSummariesJob] Refreshed summaries for event #{event.name}")
  end
end
