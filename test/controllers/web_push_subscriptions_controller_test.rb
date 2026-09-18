require "test_helper"

class WebPushSubscriptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:scout_user)
    @original_vapid = ENV.to_h.slice("VAPID_PUBLIC_KEY", "VAPID_PRIVATE_KEY")
    sign_in_as(@user)
  end

  test "creates subscription" do
    assert_difference("WebPushSubscription.count", 1) do
      post web_push_subscriptions_path,
           params: {
             subscription: {
               endpoint: "https://push.example.com/subscriptions/new-1",
               keys: {
                 p256dh: "key1",
                 auth: "auth1"
               }
             }
           },
           as: :json
    end

    assert_response :success
  end

  test "reassigns endpoint to the current user on shared device" do
    shared_endpoint = "https://push.example.com/subscriptions/shared-1"
    WebPushSubscription.create!(
      user: users(:admin_user),
      endpoint: shared_endpoint,
      p256dh: "old-key",
      auth: "old-auth"
    )

    assert_no_difference("WebPushSubscription.count") do
      post web_push_subscriptions_path,
           params: {
             subscription: {
               endpoint: shared_endpoint,
               keys: {
                 p256dh: "new-key",
                 auth: "new-auth"
               }
             }
           },
           as: :json
    end

    assert_response :success
    record = WebPushSubscription.find_by(endpoint: shared_endpoint)
    assert_equal @user.id, record.user_id
    assert_equal "new-key", record.p256dh
    assert_equal "new-auth", record.auth
  end

  test "unsubscribe removes subscription by endpoint" do
    subscription = WebPushSubscription.create!(
      user: @user,
      endpoint: "https://push.example.com/subscriptions/remove-1",
      p256dh: "key2",
      auth: "auth2"
    )

    assert_difference("WebPushSubscription.count", -1) do
      delete unsubscribe_web_push_subscriptions_path, params: { endpoint: subscription.endpoint }, as: :json
    end

    assert_response :success
  end

  test "sends test notification when subscription exists" do
    WebPushSubscription.create!(
      user: @user,
      endpoint: "https://push.example.com/subscriptions/test-1",
      p256dh: "key-test",
      auth: "auth-test"
    )

    ENV["VAPID_PUBLIC_KEY"] = "public"
    ENV["VAPID_PRIVATE_KEY"] = "private"

    with_stubbed_webpush_success do
      post test_notification_web_push_subscriptions_path, as: :json
    end

    assert_response :success
  ensure
    ENV["VAPID_PUBLIC_KEY"] = @original_vapid["VAPID_PUBLIC_KEY"]
    ENV["VAPID_PRIVATE_KEY"] = @original_vapid["VAPID_PRIVATE_KEY"]
  end

  test "test notification returns error without subscription" do
    post test_notification_web_push_subscriptions_path, as: :json

    assert_response :unprocessable_entity
  end

  private

  def with_stubbed_webpush_success
    singleton = class << Webpush; self; end
    singleton.send(:alias_method, :__original_payload_send_for_test, :payload_send)
    singleton.send(:define_method, :payload_send) do |**_kwargs|
      true
    end

    yield
  ensure
    singleton.send(:alias_method, :payload_send, :__original_payload_send_for_test)
    singleton.send(:remove_method, :__original_payload_send_for_test)
  end
end
