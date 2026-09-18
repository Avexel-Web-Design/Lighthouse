require "test_helper"

class PickListsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin_user)
    @event = events(:championship)
    @pick_list = pick_lists(:championship_picks)
    sign_in_as(@user)
    select_event(@event)
  end

  # --- Index ---

  test "should get index" do
    get pick_lists_path
    assert_response :success
  end

  test "lead can get index" do
    sign_out :user
    sign_in_as(users(:lead_user))
    select_event(@event)

    get pick_lists_path
    assert_response :success
  end

  test "scout sees scoped index via policy_scope" do
    sign_out :user
    sign_in_as(users(:scout_user))
    select_event(@event)

    # policy_scope filters to user's own pick lists; doesn't deny access
    get pick_lists_path
    assert_response :success
  end

  test "index requires event" do
    reset!
    sign_in_as(@user)

    get pick_lists_path
    assert_redirected_to events_path
  end

  # --- Show ---

  test "should get show" do
    get pick_list_path(@pick_list)
    assert_response :success
    assert_includes response.body, "Mark picked"
    assert_includes response.body, "Sort by avg points"
  end

  test "lead can get show" do
    sign_out :user
    sign_in_as(users(:lead_user))
    select_event(@event)

    get pick_list_path(@pick_list)
    assert_response :success
  end

  test "scout cannot get show" do
    sign_out :user
    sign_in_as(users(:scout_user))
    select_event(@event)

    get pick_list_path(@pick_list)
    assert_response :not_found
  end

  # --- New ---

  test "admin should get new" do
    get new_pick_list_path
    assert_response :success
    assert_includes response.body, "Selected Teams"
    assert_includes response.body, "Add"
    assert_includes response.body, "Sort by recent points"
  end

  test "scout cannot get new" do
    sign_out :user
    sign_in_as(users(:scout_user))
    select_event(@event)

    get new_pick_list_path
    assert_response :redirect
  end

  # --- Create ---

  test "admin should create pick list" do
    assert_difference("PickList.count", 1) do
      post pick_lists_path, params: {
        pick_list: {
          name: "Test Pick List",
          entries: [ frc_teams(:team_254).id, frc_teams(:team_118).id ]
        }
      }
    end

    assert_equal [ frc_teams(:team_254).id, frc_teams(:team_118).id ], PickList.last.entries
    assert_redirected_to pick_list_path(PickList.last)
  end

  test "update accepts json reorder payload" do
    patch pick_list_path(@pick_list), params: { entries: [ frc_teams(:team_118).id, frc_teams(:team_254).id ] }, as: :json

    assert_response :success
    @pick_list.reload
    assert_equal [ frc_teams(:team_118).id, frc_teams(:team_254).id ], @pick_list.entries
  end

  # --- Authentication ---

  test "unauthenticated user is redirected" do
    sign_out :user

    get pick_lists_path
    assert_redirected_to new_user_session_path
  end
end
