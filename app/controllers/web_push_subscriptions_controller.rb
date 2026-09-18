class WebPushSubscriptionsController < ApplicationController
  def create
    authorize :web_push_subscription, :create?

    permitted = subscription_params
    endpoint = permitted[:endpoint]
    keys = permitted[:keys] || {}

    if endpoint.blank? || keys[:p256dh].blank? || keys[:auth].blank?
      render json: { error: "Invalid subscription payload" }, status: :unprocessable_entity
      return
    end

    record = current_user.web_push_subscriptions.find_or_initialize_by(endpoint: endpoint)
    record.assign_attributes(
      user: current_user,
      p256dh: keys[:p256dh],
      auth: keys[:auth],
      user_agent: request.user_agent,
      last_seen_at: Time.current
    )
    record.save!

    render json: { status: "ok" }
  rescue StandardError => e
    Rails.logger.warn("[WebPushSubscriptionsController] create failed: #{e.message}")
    render json: { error: "Failed to save subscription" }, status: :unprocessable_entity
  end

  def unsubscribe
    authorize :web_push_subscription, :unsubscribe?

    endpoint = params[:endpoint].to_s
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
    Rails.logger.warn("[WebPushSubscriptionsController] test notification failed: #{e.message}")
    render json: { error: "Failed to send test notification" }, status: :unprocessable_entity
  end

  private

  def subscription_params
    params.require(:subscription).permit(:endpoint, keys: %i[p256dh auth])
  end
end
