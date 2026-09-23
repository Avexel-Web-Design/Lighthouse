require "test_helper"

class TeamEventSummaryTest < ActiveSupport::TestCase
  # TeamEventSummary is backed by a materialized view, not a regular table.

  test "uses team_event_summaries table" do
    assert_equal "team_event_summaries", TeamEventSummary.table_name
  end

  test "readonly? returns true" do
    summary = TeamEventSummary.allocate
    assert summary.readonly?
  end

  test "responds to event association" do
    assert TeamEventSummary.reflect_on_association(:event).present?
    assert_equal :belongs_to, TeamEventSummary.reflect_on_association(:event).macro
  end

  test "responds to frc_team association" do
    assert TeamEventSummary.reflect_on_association(:frc_team).present?
    assert_equal :belongs_to, TeamEventSummary.reflect_on_association(:frc_team).macro
  end

  test "responds to refresh!" do
    assert_respond_to TeamEventSummary, :refresh!
  end

  test "refresh populates an empty view inside a transaction" do
    TeamEventSummary.connection.execute("REFRESH MATERIALIZED VIEW team_event_summaries WITH NO DATA")
    TeamEventSummary.refresh!
    assert TeamEventSummary.exists?(event: events(:championship))
    assert_equal 1, TeamEventSummary.connection.select_value("SELECT 1")
  end

  test "fallback handles wrapped errors without a PostgreSQL result" do
    error = begin
      begin
        raise StandardError, "adapter wrapper"
      rescue StandardError
        raise ActiveRecord::StatementInvalid, "view has not been populated"
      end
    rescue ActiveRecord::StatementInvalid => raised
      raised
    end
    assert TeamEventSummary.send(:unpopulated_view_error?, error)
    assert_not TeamEventSummary.send(:unpopulated_view_error?, ActiveRecord::StatementInvalid.new("unrelated error"))
  end

  test "exposes average defense rating" do
    TeamEventSummary.refresh!

    summary = TeamEventSummary.find_by!(event: events(:championship), frc_team: frc_teams(:team_254))
    assert_in_delta 4.67, summary.avg_defense_rating.to_f, 0.01
  end
end
