require "test_helper"

class PushNotificationServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:admin_user)
    @assignment = scouting_assignments(:admin_qm2)
    @original_vapid = ENV.to_h.slice("VAPID_PUBLIC_KEY", "VAPID_PRIVATE_KEY")
  end

  test "sends payload to each subscription" do
    ENV["VAPID_PUBLIC_KEY"] = "public"
    ENV["VAPID_PRIVATE_KEY"] = "private"

    captured = []
    with_stubbed_webpush(captured) do
      PushNotificationService.new(@user).send_assignment_notification!(assignment: @assignment, matches_ahead: 2)
    end

    assert_equal 1, captured.length
    assert_equal web_push_subscriptions(:admin_phone).endpoint, captured.first[:endpoint]
    assert_equal "public", captured.first[:vapid][:public_key]
    assert_equal "private", captured.first[:vapid][:private_key]
  ensure
    ENV["VAPID_PUBLIC_KEY"] = @original_vapid["VAPID_PUBLIC_KEY"]
    ENV["VAPID_PRIVATE_KEY"] = @original_vapid["VAPID_PRIVATE_KEY"]
  end

  test "returns false when delivery fails" do
    ENV["VAPID_PUBLIC_KEY"] = "public"
    ENV["VAPID_PRIVATE_KEY"] = "private"

    with_stubbed_webpush_error do
      delivered = PushNotificationService.new(@user).send_assignment_notification!(
        assignment: @assignment,
        matches_ahead: 2
      )

      assert_not delivered
    end
  ensure
    ENV["VAPID_PUBLIC_KEY"] = @original_vapid["VAPID_PUBLIC_KEY"]
    ENV["VAPID_PRIVATE_KEY"] = @original_vapid["VAPID_PRIVATE_KEY"]
  end

  test "send_test_notification succeeds with subscription" do
    ENV["VAPID_PUBLIC_KEY"] = "public"
    ENV["VAPID_PRIVATE_KEY"] = "private"

    with_stubbed_webpush([]) do
      delivered = PushNotificationService.new(@user).send_test_notification!
      assert delivered
    end
  ensure
    ENV["VAPID_PUBLIC_KEY"] = @original_vapid["VAPID_PUBLIC_KEY"]
    ENV["VAPID_PRIVATE_KEY"] = @original_vapid["VAPID_PRIVATE_KEY"]
  end

  test "does not deliver when either VAPID key is missing" do
    %w[VAPID_PUBLIC_KEY VAPID_PRIVATE_KEY].each do |missing_key|
      ENV["VAPID_PUBLIC_KEY"] = "public"
      ENV["VAPID_PRIVATE_KEY"] = "private"
      ENV.delete(missing_key)
      captured = []

      with_stubbed_webpush(captured) do
        assert_not PushNotificationService.new(@user).send_test_notification!
      end
      assert_empty captured
      assert @user.web_push_subscriptions.exists?
    end
  ensure
    ENV["VAPID_PUBLIC_KEY"] = @original_vapid["VAPID_PUBLIC_KEY"]
    ENV["VAPID_PRIVATE_KEY"] = @original_vapid["VAPID_PRIVATE_KEY"]
  end

  private

  def with_stubbed_webpush(captured)
    singleton = class << Webpush; self; end
    singleton.send(:alias_method, :__original_payload_send_for_test, :payload_send)
    singleton.send(:define_method, :payload_send) do |**kwargs|
      captured << kwargs
      true
    end

    yield
  ensure
    singleton.send(:alias_method, :payload_send, :__original_payload_send_for_test)
    singleton.send(:remove_method, :__original_payload_send_for_test)
  end

  def with_stubbed_webpush_error
    singleton = class << Webpush; self; end
    singleton.send(:alias_method, :__original_payload_send_for_test, :payload_send)
    singleton.send(:define_method, :payload_send) do |**_kwargs|
      raise StandardError, "simulated failure"
    end

    yield
  ensure
    singleton.send(:alias_method, :payload_send, :__original_payload_send_for_test)
    singleton.send(:remove_method, :__original_payload_send_for_test)
  end
end
