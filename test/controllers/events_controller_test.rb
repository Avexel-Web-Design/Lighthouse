require "test_helper"

class EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin_user)
    @event = events(:championship)
    sign_in_as(@user)
  end

  # --- Index ---

  test "should get index" do
    get events_path
    assert_response :success
  end

  test "scout can get index" do
    sign_out :user
    sign_in_as(users(:scout_user))

    get events_path
    assert_response :success
  end

  # --- Show ---

  test "should get show" do
    get event_path(@event)
    assert_response :success
  end

  test "scout can get show" do
    sign_out :user
    sign_in_as(users(:scout_user))

    get event_path(@event)
    assert_response :success
  end

  # --- Select ---

  test "should select event and set session" do
    post select_event_path(@event)
    assert_redirected_to root_path
  end

  test "scout can select event" do
    sign_out :user
    sign_in_as(users(:scout_user))

    post select_event_path(@event)
    assert_redirected_to root_path
  end

  # --- New ---

  test "edit and invalid update preserve every supported event type" do
    Event.event_types.each_key do |type|
      @event.update!(event_type: type)
      get edit_event_path(@event)
      assert_response :success
      assert_select "select[name='event[event_type]'] option[selected][value='#{type}']", count: 1
      patch event_path(@event), params: { event: { name: "", event_type: type } }
      assert_response :unprocessable_entity
      assert_select "select[name='event[event_type]'] option[selected][value='#{type}']", count: 1
    end
  end

  test "admin should get new" do
    get new_event_path
    assert_response :success
  end

  test "analyst should not get new" do
    sign_out :user
    sign_in_as(users(:lead_user))

    get new_event_path
    assert_response :redirect
  end

  test "scout should not get new" do
    sign_out :user
    sign_in_as(users(:scout_user))

    get new_event_path
    assert_response :redirect
  end

  # --- Create ---

  test "admin should create event" do
    assert_difference("Event.count", 1) do
      post events_path, params: {
        event: {
          name: "Test Regional",
          tba_key: "2026testcreate",
          year: 2026,
          start_date: "2026-03-01",
          end_date: "2026-03-03",
          event_type: 0
        }
      }
    end
    assert_redirected_to event_path(Event.last)
  end

  test "analyst should not create event" do
    sign_out :user
    sign_in_as(users(:lead_user))

    assert_no_difference("Event.count") do
      post events_path, params: {
        event: {
          name: "Lead Regional",
          tba_key: "2026leadtest",
          year: 2026,
          start_date: "2026-03-01",
          end_date: "2026-03-03",
          event_type: 0
        }
      }
    end
    assert_response :redirect
  end

  test "scout should not create event" do
    sign_out :user
    sign_in_as(users(:scout_user))

    assert_no_difference("Event.count") do
      post events_path, params: {
        event: {
          name: "Scout Regional",
          tba_key: "2026scouttest",
          year: 2026,
          start_date: "2026-03-01",
          end_date: "2026-03-03",
          event_type: 0
        }
      }
    end
    # Pundit redirects unauthorized
    assert_response :redirect
  end

  test "sync shows helpful error when TBA is not configured" do
    original_api_key = ENV["TBA_API_KEY"]
    ENV.delete("TBA_API_KEY")

    begin
      post sync_event_path(@event)
    ensure
      ENV["TBA_API_KEY"] = original_api_key
    end

    assert_redirected_to event_path(@event)
    follow_redirect!
    assert_includes response.body, "TBA sync is unavailable"
  end

  # --- Destroy ---

  test "admin should destroy event" do
    event = Event.create!(name: "Deletable Event", tba_key: "2026deleteme", year: 2026, event_type: 0)

    assert_difference("Event.count", -1) do
      delete event_path(event)
    end
    assert_redirected_to events_path
  end

  test "analyst should not destroy event" do
    sign_out :user
    sign_in_as(users(:lead_user))

    assert_no_difference("Event.count") do
      delete event_path(@event)
    end
    assert_response :redirect
  end

  test "scout should not destroy event" do
    sign_out :user
    sign_in_as(users(:scout_user))

    assert_no_difference("Event.count") do
      delete event_path(@event)
    end
    assert_response :redirect
  end

  # --- Authentication ---

  test "unauthenticated user is redirected from index" do
    sign_out :user

    get events_path
    assert_redirected_to new_user_session_path
  end
end
