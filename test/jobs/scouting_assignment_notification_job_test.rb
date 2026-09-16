require "test_helper"

class ScoutingAssignmentNotificationJobTest < ActiveJob::TestCase
  setup do
    @event = events(:championship)
    @assignment = scouting_assignments(:admin_qm2)
  end

  test "marks 1-match-ahead notification timestamp for shift start" do
    # Remove Q1 assignment so Q2 becomes a shift start (not mid-shift)
    scouting_assignments(:admin_qm1).destroy!

    @assignment.update!(notified_1_at: nil)
    matches(:qm2).update!(red_score: nil, blue_score: nil)
    # Clear later matches so Q1 is the latest completed (Q2 is 1 ahead)
    matches(:qm3).update!(red_score: nil, blue_score: nil)
    matches(:qm4).update!(red_score: nil, blue_score: nil)
    ENV["VAPID_PUBLIC_KEY"] = "public"
    ENV["VAPID_PRIVATE_KEY"] = "private"

    captured = []
    with_stubbed_webpush(captured) do
      ScoutingAssignmentNotificationJob.perform_now(@event.id)
    end

    assert_equal 1, captured.length
    assert @assignment.reload.notified_1_at.present?
  ensure
    ENV.delete("VAPID_PUBLIC_KEY")
    ENV.delete("VAPID_PRIVATE_KEY")
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
    ENV.delete("VAPID_PUBLIC_KEY")
    ENV.delete("VAPID_PRIVATE_KEY")
  end

  test "does not mark notification when delivery fails" do
    scouting_assignments(:admin_qm1).destroy!
    @assignment.update!(notified_1_at: nil)
    matches(:qm2).update!(red_score: nil, blue_score: nil)
    ENV["VAPID_PUBLIC_KEY"] = "public"
    ENV["VAPID_PRIVATE_KEY"] = "private"

    with_stubbed_webpush_error do
      ScoutingAssignmentNotificationJob.perform_now(@event.id)
    end

    assert_nil @assignment.reload.notified_1_at
  ensure
    ENV.delete("VAPID_PUBLIC_KEY")
    ENV.delete("VAPID_PRIVATE_KEY")
  end

  test "claims the threshold before delivery so an overlapping run skips it" do
    scouting_assignments(:admin_qm1).destroy!
    @event.matches.where(comp_level: "qm").where.not(id: matches(:qm1).id).update_all(red_score: nil, blue_score: nil)
    original_public = ENV["VAPID_PUBLIC_KEY"]
    original_private = ENV["VAPID_PRIVATE_KEY"]
    ENV["VAPID_PUBLIC_KEY"] = "public"
    ENV["VAPID_PRIVATE_KEY"] = "private"
    captured = []

    with_stubbed_webpush(captured, after_send: -> {
      assert @assignment.reload.notified_1_at.present?
      ScoutingAssignmentNotificationJob.perform_now(@event.id)
    }) do
      ScoutingAssignmentNotificationJob.perform_now(@event.id)
      ScoutingAssignmentNotificationJob.perform_now(@event.id)
    end

    assert_equal 1, captured.size
  ensure
    ENV["VAPID_PUBLIC_KEY"] = original_public
    ENV["VAPID_PRIVATE_KEY"] = original_private
  end

  test "failed delivery releases the claim for a later attempt" do
    scouting_assignments(:admin_qm1).destroy!
    @event.matches.where(comp_level: "qm").where.not(id: matches(:qm1).id).update_all(red_score: nil, blue_score: nil)
    original_public = ENV["VAPID_PUBLIC_KEY"]
    original_private = ENV["VAPID_PRIVATE_KEY"]
    ENV["VAPID_PUBLIC_KEY"] = "public"
    ENV["VAPID_PRIVATE_KEY"] = "private"

    with_stubbed_webpush_error do
      ScoutingAssignmentNotificationJob.perform_now(@event.id)
    end
    assert_nil @assignment.reload.notified_1_at

    captured = []
    with_stubbed_webpush(captured) do
      ScoutingAssignmentNotificationJob.perform_now(@event.id)
    end
    assert_equal 1, captured.size
    assert @assignment.reload.notified_1_at.present?
  ensure
    ENV["VAPID_PUBLIC_KEY"] = original_public
    ENV["VAPID_PRIVATE_KEY"] = original_private
  end

  private

  def with_stubbed_webpush(captured, after_send: nil)
    singleton = class << Webpush; self; end
    singleton.send(:alias_method, :__original_payload_send_for_test, :payload_send)
    singleton.send(:define_method, :payload_send) do |**kwargs|
      captured << kwargs
      after_send&.call
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
