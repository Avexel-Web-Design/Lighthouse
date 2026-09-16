class WebPushSubscriptionsController < ApplicationController
  MAX_ENDPOINT_LENGTH = 2000
  MAX_KEY_LENGTH = 500

  def create
    authorize :web_push_subscription, :create?

    permitted = subscription_params
    endpoint = permitted[:endpoint].to_s.strip.first(MAX_ENDPOINT_LENGTH)
    keys = permitted[:keys] || {}

    if endpoint.blank? || keys[:p256dh].blank? || keys[:auth].blank?
      render json: { error: "Invalid subscription payload" }, status: :unprocessable_entity
      return
    end

    record = WebPushSubscription.find_or_initialize_by(endpoint: endpoint)
    record.assign_attributes(
      user: current_user,
      p256dh: keys[:p256dh].to_s.strip.first(MAX_KEY_LENGTH),
      auth: keys[:auth].to_s.strip.first(MAX_KEY_LENGTH),
      user_agent: request.user_agent.to_s.first(500),
      last_seen_at: Time.current
    )
    if record.save
      render json: { status: "ok" }
    else
      render json: { error: "Invalid subscription payload" }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.warn("[WebPushSubscriptionsController] create failed: #{e.class}: #{e.message}")
    render json: { error: "Failed to save subscription" }, status: :unprocessable_entity
  end

  def unsubscribe
    authorize :web_push_subscription, :unsubscribe?

    endpoint = unsubscribe_params[:endpoint].to_s.strip.first(MAX_ENDPOINT_LENGTH)
    if endpoint.blank?
      render json: { error: "Missing endpoint" }, status: :unprocessable_entity
      return
    end

    current_user.web_push_subscriptions.where(endpoint: endpoint).delete_all
    render json: { status: "ok" }
  end

  def test_notification
    authorize :web_push_subscription, :create?

    sent = PushNotificationService.new(current_user).send_test_notification!

    if sent
      render json: { status: "ok" }
    else
      render json: { error: "No active push subscription found" }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.warn("[WebPushSubscriptionsController] test notification failed: #{e.class}: #{e.message}")
    render json: { error: "Failed to send test notification" }, status: :unprocessable_entity
  end

  private

  def subscription_params
    params.require(:subscription).permit(:endpoint, keys: %i[p256dh auth])
  end

  def unsubscribe_params
    params.permit(:endpoint)
  end
end
