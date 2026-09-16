# Provides same-origin verification for sync endpoints that skip CSRF token
# verification. When a valid X-CSRF-Token header is present (and verifies
# against the session) the request is allowed through. Token-based API
# clients (Authorization: Bearer) bypass the origin check and rely on
# ApiAuthenticatable. Otherwise we require the Origin / Referer to match
# the request scheme, host, and port — browsers always include Origin on
# cross-origin POSTs, so a CSRF attack from another site will be blocked.
module SyncCsrfProtection
  extend ActiveSupport::Concern

  private

  def verify_sync_origin
    # Token-based API clients don't send Origin; authentication handles them.
    return if request.headers["Authorization"].present?

    # Allow if a valid CSRF token is present and verifies against the session
    token = request.headers["X-CSRF-Token"]
    return if token.present? && valid_authenticity_token?(session, token)

    # Fallback: verify the request originated from the same origin
    # (scheme + host + port), not just the host.
    origin = request.headers["Origin"]
    return if origin.present? && same_origin?(origin)

    referer = request.headers["Referer"]
    return if referer.present? && same_origin?(referer)

    head :forbidden
  end

  def same_origin?(url)
    uri = URI.parse(url.to_s)
    uri.host == request.host && uri.scheme == request.scheme && uri.port == request.port
  rescue URI::InvalidURIError
    false
  end
end
