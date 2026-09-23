require "test_helper"
require_relative "../../db/migrate/20260316000000_add_p1_data_integrity_indexes"

class P1DataIntegrityMigrationTest < ActiveSupport::TestCase
  test "migration round trip preserves counted summaries without consulting model enums" do
    connection = ActiveRecord::Base.connection
    scouting_entries(:entry_qm1_254).update!(status: :approved)
    scouting_entries(:entry_qm2_254).update!(status: :flagged)
    TeamEventSummary.refresh!
    before_rows = connection.select_all("SELECT * FROM team_event_summaries ORDER BY event_id, frc_team_id").to_a
    before_definition = connection.select_value("SELECT pg_get_viewdef('team_event_summaries')")
    statuses = ScoutingEntry.method(:statuses)

    begin
      ScoutingEntry.define_singleton_method(:statuses) { raise "Migration must not depend on model enums" }
      suppress_messages do
        migration = AddP1DataIntegrityIndexes.new
        migration.down
        assert connection.index_exists?(:web_push_subscriptions, %i[user_id endpoint], unique: true)
        migration.up
      end
    ensure
      ScoutingEntry.define_singleton_method(:statuses, statuses)
    end

    assert_equal before_definition, connection.select_value("SELECT pg_get_viewdef('team_event_summaries')")
    assert_equal before_rows, connection.select_all("SELECT * FROM team_event_summaries ORDER BY event_id, frc_team_id").to_a
    assert connection.index_exists?(:matches, %i[event_id comp_level set_number match_number], unique: true)
    assert connection.index_exists?(:users, "lower((username)::text)", unique: true)
    assert connection.index_exists?(:web_push_subscriptions, :endpoint, unique: true)
    assert_not connection.index_exists?(:web_push_subscriptions, %i[user_id endpoint])
    TeamEventSummary.refresh!
  end

  private

  def suppress_messages(&block)
    ActiveRecord::Migration.suppress_messages(&block)
  end
end
