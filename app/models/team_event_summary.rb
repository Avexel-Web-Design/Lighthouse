class TeamEventSummary < ApplicationRecord
  self.table_name = "team_event_summaries"

  # This is a read-only model backed by a materialized view
  def readonly?
    true
  end

  # Associations
  belongs_to :event
  belongs_to :frc_team

  # Refreshes the materialized view.
  # Uses CONCURRENTLY when possible (requires a unique index and prior population).
  # Falls back to a blocking refresh on the first run when the view is unpopulated.
  def self.refresh!
    connection.execute("REFRESH MATERIALIZED VIEW CONCURRENTLY #{table_name}")
  rescue ActiveRecord::StatementInvalid => e
    raise unless unpopulated_view_error?(e)

    connection.execute("REFRESH MATERIALIZED VIEW #{table_name}")
  end

  # Detects the "view has not been populated" precondition failure via its
  # SQLSTATE (55000, object_not_in_prerequisite_state) instead of matching
  # English message text, which varies across PostgreSQL versions. The
  # message match remains as a fallback for adapters that hide the cause.
  def self.unpopulated_view_error?(error)
    if defined?(PG::Result)
      sqlstate = error.cause&.result&.error_field(PG::Result::PG_DIAG_SQLSTATE)
      return true if sqlstate == "55000"
    end

    error.message.match?(/has not been populated|is not populated/i)
  end
  private_class_method :unpopulated_view_error?
end
