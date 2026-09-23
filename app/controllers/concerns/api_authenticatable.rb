# frozen_string_literal: true

module ApiAuthenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_api_user!
    rescue_from ActiveRecord::RecordNotFound, with: :api_record_not_found
  end

  private

  def authenticate_api_user!
    token = request.headers["Authorization"]&.delete_prefix("Bearer ")
    @current_api_user = User.find_by(api_token: token) if token.present?

    unless @current_api_user
      render json: { error: "Unauthorized. Provide a valid Bearer token." }, status: :unauthorized
    end
  end

  def current_api_user
    @current_api_user
  end

  def api_record_not_found
    render json: { error: "Record not found." }, status: :not_found
  end
end
