# The development and test issuer (ADR 0003). Mints the same claim set the real
# auth service does, signed with a checked-in keypair, so the bearer path is the
# same code in every environment. Golden fixtures keep the claim set honest.
class StubIssuer
  ISSUER = "https://auth.stub".freeze
  CLIENT_ID = "noted-stub".freeze
  DIRECTORY = Rails.root.join("config/auth_stub")

  class << self
    def available? = AuthService.stubbed?

    def users = @users ||= YAML.load_file(Rails.root.join("config/dev_users.yml")).map(&:symbolize_keys)

    def find(email) = users.find { |user| user[:email] == email }

    def identity(email) = find(email) || identity_for(User.find_by(email: email))

    def identity_for(user)
      return if user.nil?

      { sub: user.auth_sub || user.id, email: user.email, name: user.name }
    end

    def access_token(user, sid: SecureRandom.hex(16), expires_in: 15.minutes, **overrides)
      user = user.symbolize_keys
      encode(claims(user, sid: sid, expires_in: expires_in).merge(overrides))
    end

    def logout_token(sid:, subject:)
      encode({
        iss: ISSUER, aud: CLIENT_ID, sub: subject, sid: sid,
        iat: Time.current.to_i, exp: 2.minutes.from_now.to_i, jti: SecureRandom.uuid,
        events: { LogoutToken::EVENT => {} }
      })
    end

    def jwks = JSON.parse(DIRECTORY.join("jwks.json").read)

    def encode(payload, typ: "JWT")
      JWT.encode(payload.compact, key, "RS256", typ: typ, kid: jwk.kid)
    end

    private

    def claims(user, sid:, expires_in:)
      now = Time.current.to_i

      {
        iss: ISSUER, sub: user.fetch(:sub), aud: CLIENT_ID,
        iat: now, exp: now + expires_in.to_i, jti: SecureRandom.uuid,
        scope: "openid email profile offline_access", sid: sid,
        email: user.fetch(:email), email_verified: true, name: user[:name]
      }
    end

    def key = @key ||= OpenSSL::PKey::RSA.new(DIRECTORY.join("private.pem").read)

    def jwk = @jwk ||= JWT::JWK.new(key, kid_generator: JWT::JWK::Thumbprint)
  end
end
