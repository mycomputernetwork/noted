module AuthService
  class Error < StandardError; end

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
