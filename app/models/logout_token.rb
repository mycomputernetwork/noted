class LogoutToken
  EVENT = "http://schemas.openid.net/event/backchannel-logout".freeze

  def self.verify(token)
    claims = TokenVerifier.new.verify(token)

    raise AuthService::Error, "logout token carries a nonce" if claims.raw.key?("nonce")
    raise AuthService::Error, "not a logout token" unless claims.raw.dig("events", EVENT)
    raise AuthService::Error, "logout token without sid" if claims.sid.blank?

    claims
  end
end
