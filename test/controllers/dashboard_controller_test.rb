require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @user = users(:admin_user)
    @event = events(:championship)
    sign_in_as(@user)
  end

  test "should get index with event selected" do
    select_event(@event)

    get root_path
    assert_response :success
  end

  test "should redirect to events without event selected" do
    get root_path
    assert_response :redirect
    assert_redirected_to events_path
  end

  test "should redirect to sign in when not authenticated" do
    sign_out :user

    get root_path
    assert_response :redirect
    assert_redirected_to new_user_session_path
  end

  test "any role redirects to events without event" do
    sign_out :user
    sign_in_as(users(:scout_user))

    get root_path
    assert_response :redirect
    assert_redirected_to events_path
  end

  test "any role can access dashboard with event" do
    sign_out :user
    sign_in_as(users(:scout_user))
    select_event(@event)

    get root_path
    assert_response :success
  end

  test "dashboard displays scout accuracy leaderboard for admins" do
    select_event(@event)

    get root_path
    assert_response :success
    assert_select "h2", text: "Scout Accuracy Leaderboard"
  end

  test "dashboard does not display scout accuracy leaderboard for non-admins" do
    sign_out :user
    sign_in_as(users(:lead_user))
    select_event(@event)

    get root_path
    assert_response :success
    assert_select "h2", text: "Scout Accuracy Leaderboard", count: 0
  end

  test "dashboard shows accuracy data for scouts with scored matches" do
    select_event(@event)

    get root_path
    assert_response :success
    assert_match(/pts off/, response.body)
  end

  test "dashboard recent entries shows admin approved status" do
    scouting_entries(:entry_qm1_254).update!(status: :approved)
    select_event(@event)

    get root_path

    assert_response :success
    assert_includes response.body, "Admin Approved"
  end

  test "dashboard shows active shift status for the current user" do
    Match.where(event: @event, comp_level: "qm").update_all(red_score: nil, blue_score: nil)
    select_event(@event)

    get root_path
    assert_response :success
    assert_match "My Shift", response.body
    assert_match "Current: Q1", response.body
    assert_match "2 matches left in shift", response.body
  end

  test "dashboard shows upcoming shift start and matches until it begins" do
    Match.where(event: @event, comp_level: "qm").update_all(red_score: nil, blue_score: nil)
    matches(:qm1).update!(red_score: 180, blue_score: 120)
    ScoutingAssignment.where(event: @event, user: @user).destroy_all
    ScoutingAssignment.create!(event: @event, user: @user, match: matches(:qm4))
    select_event(@event)

    get root_path
    assert_response :success
    assert_match "Current: Q2", response.body
    assert_match "Starts in 2 matches", response.body
    assert_match "Q4", response.body
  end

  test "dashboard enqueues async auto-sync when TBA is configured" do
    select_event(@event)
    original_api_key = ENV["TBA_API_KEY"]
    ENV["TBA_API_KEY"] = "test-key"
    clear_enqueued_jobs

    assert_enqueued_with(job: AutoSyncEventJob, args: [ @event.id ]) do
      get root_path
    end
  ensure
    clear_enqueued_jobs
    ENV["TBA_API_KEY"] = original_api_key
  end
end
