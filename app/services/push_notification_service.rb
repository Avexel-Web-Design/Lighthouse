class PushNotificationService
  def initialize(user)
    @user = user
  end

  def send_assignment_notification!(assignment:, matches_ahead:)
    payload = build_payload(assignment, matches_ahead)
    send_payload_to_subscriptions(payload)
  end

  def send_test_notification!
    payload = {
      title: "Lighthouse test notification",
      body: "Push notifications are enabled on this device.",
      url: Rails.application.routes.url_helpers.scouting_assignments_path,
      tag: "push-test-#{user.id}",
      icon: "/icon.png"
    }

    send_payload_to_subscriptions(payload)
  end

  private

  attr_reader :user

  def send_payload_to_subscriptions(payload)
    return false unless vapid_configured?

    delivered = false

    user.web_push_subscriptions.find_each do |subscription|
      begin
        Webpush.payload_send(
          message: payload.to_json,
          endpoint: subscription.endpoint,
          p256dh: subscription.p256dh,
          auth: subscription.auth,
          vapid: vapid_options
        )
        delivered = true
      rescue Webpush::ExpiredSubscription, Webpush::InvalidSubscription
        subscription.destroy
      rescue StandardError => e
        Rails.logger.warn("[PushNotificationService] Failed push for user #{user.id}: #{e.message}")
      end
    end

    delivered
  end

  def build_payload(assignment, matches_ahead)
    {
      title: "Scouting shift reminder",
      body: "Your shift starting at #{assignment.match.display_name} is #{matches_ahead} match#{"es" unless matches_ahead == 1} away.",
      url: Rails.application.routes.url_helpers.new_scouting_entry_path(
        match_id: assignment.match_id,
        frc_team_id: assignment.frc_team_id
      ),
      tag: "shift-#{assignment.id}-#{matches_ahead}",
      icon: "/icon.png"
    }
  end

  def vapid_options
    {
      subject: ENV["VAPID_SUBJECT"].presence || "mailto:scouting@lighthouse.local",
      public_key: ENV["VAPID_PUBLIC_KEY"],
      private_key: ENV["VAPID_PRIVATE_KEY"]
    }
  end

  def vapid_configured?
    ENV["VAPID_PUBLIC_KEY"].present? && ENV["VAPID_PRIVATE_KEY"].present?
  end
end
