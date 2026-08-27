# Vendored rather than published as a gem: at three apps, copying is cheaper
# than versioning (ADR 0003). Golden fixtures in spec/fixtures/auth keep the
# copies honest.
class TokenVerifier
  CACHE_KEY = "auth_service/jwks".freeze
  CACHE_TTL = 12.hours

  def initialize(issuer: AuthService.issuer, audience: AuthService.audiences)
    @issuer = issuer
    @audience = Array(audience)
  end

  def verify(token)
    payload, = JWT.decode(token, nil, true,
                          algorithms: ["RS256"],
                          jwks: method(:jwks),
                          iss: issuer, verify_iss: true,
                          aud: audience, verify_aud: true,
                          verify_expiration: true)

    AuthService::Claims.from(payload)
  rescue JWT::DecodeError => e
    raise AuthService::Error, e.message
  end

  private

  attr_reader :issuer, :audience

  def jwks(options = {})
    key = "#{CACHE_KEY}/#{issuer}"
    Rails.cache.delete(key) if options[:invalidate]

    JWT::JWK::Set.new(Rails.cache.fetch(key, expires_in: CACHE_TTL) { fetch_jwks })
  end

  def fetch_jwks
    return StubIssuer.jwks if AuthService.stubbed?

    response = Net::HTTP.get_response(URI("#{issuer}/oauth/discovery/keys"))
    raise AuthService::Error, "JWKS #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end
end
