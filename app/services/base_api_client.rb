# frozen_string_literal: true

# Shared Faraday + Rails.cache wrapper for external JSON APIs.
#
# Extracted from TbaClient / StatboticsClient to dedup connection setup,
# retry config, JSON handling, and nil-safe caching.
class BaseApiClient
  RETRY_EXCEPTIONS = [ Faraday::TimeoutError, Faraday::ConnectionFailed ].freeze

  class << self
    def build_connection(base_url:, headers: {})
      Faraday.new(url: base_url) do |f|
        headers.each { |key, value| f.headers[key] = value }
        f.request :retry, max: 3, interval: 0.5, backoff_factor: 2,
                          exceptions: RETRY_EXCEPTIONS
        f.response :json, parser_options: { symbolize_names: false }
        f.adapter Faraday.default_adapter
      end
    end
  end

  private

  # GETs a relative path with optional query params, caching the result.
  # Uses skip_nil so transient failures are not negatively cached.
  def cached_get(cache_key, path, params = {}, expires_in:, log_prefix:)
    Rails.cache.fetch(cache_key, expires_in: expires_in, skip_nil: true) do
      response = @conn.get(path.delete_prefix("/"), params)

      if response.success?
        response.body
      else
        Rails.logger.warn("[#{log_prefix}] #{path} returned #{response.status}: #{response.body}")
        nil
      end
    end
  rescue Faraday::Error => e
    Rails.logger.error("[#{log_prefix}] Request to #{path} failed: #{e.message}")
    nil
  end
end
