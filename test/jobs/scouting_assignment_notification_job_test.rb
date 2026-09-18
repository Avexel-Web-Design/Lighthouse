require "test_helper"

class ScoutingAssignmentNotificationJobTest < ActiveJob::TestCase
  setup do
    @event = events(:championship)
    @assignment = scouting_assignments(:admin_qm2)
    @original_vapid = ENV.to_h.slice("VAPID_PUBLIC_KEY", "VAPID_PRIVATE_KEY")
    matches(:qm2).update!(red_score: nil, blue_score: nil)
    matches(:qm3).update!(red_score: nil, blue_score: nil)
    matches(:qm4).update!(red_score: nil, blue_score: nil)
  end

  test "marks 1-match-ahead notification timestamp for shift start" do
    # Remove Q1 assignment so Q2 becomes a shift start (not mid-shift)
    scouting_assignments(:admin_qm1).destroy!

    @assignment.update!(notified_1_at: nil)
    ENV["VAPID_PUBLIC_KEY"] = "public"
    ENV["VAPID_PRIVATE_KEY"] = "private"

    captured = []
    with_stubbed_webpush(captured) do
      ScoutingAssignmentNotificationJob.perform_now(@event.id)
    end

    assert_equal 1, captured.length
    assert @assignment.reload.notified_1_at.present?
  ensure
    ENV["VAPID_PUBLIC_KEY"] = @original_vapid["VAPID_PUBLIC_KEY"]
    ENV["VAPID_PRIVATE_KEY"] = @original_vapid["VAPID_PRIVATE_KEY"]
  end

  test "skips notification for mid-shift assignment" do
    # admin_qm1 and admin_qm2 are contiguous — Q2 is mid-shift, not a shift start
    @assignment.update!(notified_1_at: nil)
    matches(:qm2).update!(red_score: nil, blue_score: nil)
    ENV["VAPID_PUBLIC_KEY"] = "public"
    ENV["VAPID_PRIVATE_KEY"] = "private"

    captured = []
    with_stubbed_webpush(captured) do
      ScoutingAssignmentNotificationJob.perform_now(@event.id)
    end

    assert_equal 0, captured.length
    assert_nil @assignment.reload.notified_1_at
  ensure
    ENV["VAPID_PUBLIC_KEY"] = @original_vapid["VAPID_PUBLIC_KEY"]
    ENV["VAPID_PRIVATE_KEY"] = @original_vapid["VAPID_PRIVATE_KEY"]
  end

  test "does not mark notification when delivery fails" do
    scouting_assignments(:admin_qm1).destroy!
    @assignment.update!(notified_1_at: nil)
    matches(:qm2).update!(red_score: nil, blue_score: nil)
    ENV["VAPID_PUBLIC_KEY"] = "public"
    ENV["VAPID_PRIVATE_KEY"] = "private"

    captured = []
    with_stubbed_webpush_error(captured) do
      ScoutingAssignmentNotificationJob.perform_now(@event.id)
    end

    assert_equal 1, captured.length
    assert_nil @assignment.reload.notified_1_at
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

  def with_stubbed_webpush_error(captured)
    singleton = class << Webpush; self; end
    singleton.send(:alias_method, :__original_payload_send_for_test, :payload_send)
    singleton.send(:define_method, :payload_send) do |**kwargs|
      captured << kwargs
      raise StandardError, "simulated failure"
    end

    yield
  ensure
    singleton.send(:alias_method, :payload_send, :__original_payload_send_for_test)
    singleton.send(:remove_method, :__original_payload_send_for_test)
  end
end
