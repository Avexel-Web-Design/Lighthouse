module JsonRequestData
  extend ActiveSupport::Concern

  private

  def json_request_data(raw)
    return {} if raw.nil?
    unless raw.is_a?(Hash) || raw.is_a?(ActionController::Parameters)
      raise ActionController::BadRequest, "Data must be an object"
    end

    ActionController::Parameters.new(data: raw).permit(data: {}).fetch(:data).to_h
  end
end
