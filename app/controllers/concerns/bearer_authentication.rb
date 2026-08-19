# Two callers reach /api/v1: native clients holding an access token from auth,
# and the web app's own JavaScript, which has a first-party cookie and no token
# (PRD §15 — the editor saves through the API). Both resolve to the same
# Current.user; nothing else in the API knows which arrived.
module BearerAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
  end

  def current_user = Current.user

  private
    def require_authentication
      Current.user = user_from_token || user_from_session

      unauthorized if Current.user.nil?
    end

    def user_from_token
      token = bearer_token or return

      claims = TokenVerifier.new.verify(token)
      User.find_by(auth_sub: claims.subject)
    rescue AuthService::Error
      nil
    end

    def user_from_session
      Current.session = Session.live.from_current_issuer.find_by(id: request.session[:noted_session])
      Current.session&.user
    end

    def bearer_token
      scheme, token = request.authorization.to_s.split(" ", 2)
      token if scheme&.casecmp("bearer")&.zero?
    end

    def unauthorized
      response.headers["WWW-Authenticate"] = %(Bearer realm="noted", error="invalid_token")
      render json: { errors: [ "Not authenticated" ] }, status: :unauthorized
    end
end
