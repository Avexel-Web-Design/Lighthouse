class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  protect_from_forgery with: :exception

  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?

  after_action :pundit_verify, unless: :skip_pundit?
  before_action :auto_sync_event, if: :should_auto_sync?

  helper_method :current_event

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActionController::InvalidAuthenticityToken, with: :invalid_authenticity_token

  private

  # Returns the currently selected event from the session, or nil.
  # Clears a stale session value when the event no longer exists.
  def current_event
    return @current_event if defined?(@current_event)

    event_id = session[:current_event_id]
    if event_id.present?
      @current_event = Event.find_by(id: event_id)
      session.delete(:current_event_id) if @current_event.nil?
    end
    @current_event
  end

  # Before action to enforce that an event is selected.
  def require_event!
    return if current_event.present?

    redirect_to events_path, alert: "Please select an event first."
  end

  # Pundit user context — returns the current Devise user.
  def pundit_user
    current_user
  end

  def user_not_authorized
    if request.format.json?
      render json: { error: "You are not authorized to perform this action." }, status: :forbidden
    else
      flash[:alert] = "You are not authorized to perform this action."
      redirect_back(fallback_location: root_path)
    end
  end

  def record_not_found
    if request.format.json?
      render json: { error: "Record not found." }, status: :not_found
    else
      redirect_back fallback_location: root_path, alert: "Record not found."
    end
  end

  def invalid_authenticity_token
    if request.format.json?
      render json: { error: "Invalid authenticity token. Please reload and try again." }, status: :forbidden
    else
      redirect_back fallback_location: root_path, alert: "Invalid authenticity token. Please reload and try again."
    end
  end

  def pundit_verify
    return if pundit_policy_authorized? || pundit_policy_scoped?
    raise Pundit::AuthorizationNotPerformedError, self.class
  end

  def skip_pundit?
    devise_controller? || self.class.ancestors.include?(ActionController::API)
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_in, keys: [ :username ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :first_name, :last_name ])
  end

  # Debounced auto-sync runs only on dashboard loads and executes in a
  # background job so page rendering is never blocked by external API calls.
  def should_auto_sync?
    request.get? &&
      request.format.html? &&
      current_user.present? &&
      current_event.present? &&
      controller_name == "dashboard" &&
      action_name == "index"
  end

  def auto_sync_event
    return unless TbaClient.configured?

    # Everything stays async to keep dashboard loads fast.
    AutoSyncEventJob.perform_later(current_event.id)
  rescue StandardError => e
    Rails.logger.warn("[ApplicationController] Auto-sync failed: #{e.message}")
  end
end
