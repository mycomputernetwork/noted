module AuthService
  class Error < StandardError; end

  DISCOVERY_CACHE_KEY = "auth_service/discovery".freeze
  DISCOVERY_CACHE_TTL = 12.hours

  Claims = Data.define(:subject, :email, :name, :sid, :raw) do
    def self.from(payload)
      new(
        subject: payload["sub"],
        email: payload["email"],
        name: payload["name"],
        sid: payload["sid"],
        raw: payload
      )
    end
  end

  class << self
    def issuer = stubbed? ? StubIssuer::ISSUER : config.fetch(:issuer)

    def client_id = stubbed? ? StubIssuer::CLIENT_ID : config.fetch(:client_id)

    def client_secret = config[:client_secret]

    # RP-initiated logout: signing out here has to end auth's session too, or
    # the next sign-in on a shared machine is silent.
    def end_session_url(redirect_uri:, id_token_hint: nil)
      endpoint = end_session_endpoint or return

      uri = URI(endpoint)
      uri.query = { id_token_hint: id_token_hint, client_id: client_id,
                    post_logout_redirect_uri: redirect_uri }.compact.to_query
      uri.to_s
    end

    def end_session_endpoint
      return if stubbed?

      Rails.cache.fetch(DISCOVERY_CACHE_KEY, expires_in: DISCOVERY_CACHE_TTL) { discover }["end_session_endpoint"]
    rescue StandardError
      nil
    end

    def discover
      response = Net::HTTP.get_response(URI("#{issuer}/.well-known/openid-configuration"))
      raise Error, "discovery #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end

    def stubbed? = mode == "stub"

    def mode
      @mode ||= ENV.fetch("AUTH_MODE") { Rails.env.local? ? "stub" : "oidc" }
    end

    def config
      @config ||= {
        issuer: ENV.fetch("AUTH_ISSUER") { Rails.application.credentials.dig(:auth, :issuer) },
        client_id: Rails.application.credentials.dig(:auth, :client_id),
        client_secret: Rails.application.credentials.dig(:auth, :client_secret)
      }
    end

    def reset!
      @mode = nil
      @config = nil
    end
  end
end
