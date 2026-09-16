ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class OfflineTestAdapter < Faraday::Adapter::Test
  def initialize(app, **options)
    super(app, nil, **options) do |stub|
      stub.get(/.*/) { [ 503, { "Content-Type" => "application/json" }, '{"error":"External requests disabled in tests"}' ] }
      stub.post(/.*/) { [ 503, { "Content-Type" => "application/json" }, '{"error":"External requests disabled in tests"}' ] }
    end
  end
end

Faraday.default_adapter = OfflineTestAdapter

# Ensure the team_event_summaries materialized view is populated in the test database.
# structure.sql creates the view, but it may not be populated after db:test:prepare.
def ensure_team_event_summaries_view!
  ActiveRecord::Base.connection.execute("REFRESH MATERIALIZED VIEW team_event_summaries")
rescue ActiveRecord::StatementInvalid
  # View doesn't exist yet or other issue — safe to ignore in test setup
end

# Create the view once at boot (covers single-process test runs)
ensure_team_event_summaries_view!

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Create the view in each parallel worker's database
    parallelize_setup do |_worker|
      ensure_team_event_summaries_view!
    end
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  private

  # Sign in a user via Devise. After sign_in, the session is available
  # on the next request. Use select_event to pick an event after signing in.
  def sign_in_as(user)
    sign_in user
    user
  end

  # Selects an event by POSTing to the select endpoint, which sets the session.
  def select_event(event)
    post select_event_path(event)
  end
end
