module SyncCsrfProtection
  extend ActiveSupport::Concern

  private

  def verify_sync_origin
    token = request.headers["X-CSRF-Token"]
    return if token.present? && valid_authenticity_token?(session, token)

    origin = request.headers["Origin"]
    source = origin.nil? ? request.headers["Referer"] : origin
    return if source.present? && same_origin?(source)

    head :forbidden
  end

  def same_origin?(url)
    uri = URI.parse(url.to_s)
    uri.host == request.host && uri.scheme == request.scheme && uri.port == request.port
  rescue URI::InvalidURIError
    false
  end
end
