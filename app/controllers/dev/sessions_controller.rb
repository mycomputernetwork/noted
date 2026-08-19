module Dev
  class SessionsController < ApplicationController
    skip_before_action :require_authentication

    before_action :ensure_stub_mode

    def create
      identity = fixture or return
      return redirect_to(sign_in_path, alert: refusal(identity)) if StubIssuer.refused?(identity)

      claims = TokenVerifier.new.verify(StubIssuer.id_token(identity))
      sign_in(User.from_claims(claims), sid: claims.sid)

      redirect_to root_path
    end

    private
      def fixture = StubIssuer.identity(params[:email]) || head(:not_found)

      def refusal(identity)
        if identity[:revoked_by_auth]
          "That account's access has been revoked."
        else
          "That account is not allowed to sign in."
        end
      end

      def ensure_stub_mode
        head :not_found unless StubIssuer.available?
      end
  end
end
