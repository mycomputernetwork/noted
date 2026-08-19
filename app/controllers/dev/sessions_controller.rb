module Dev
  class SessionsController < ApplicationController
    skip_before_action :require_authentication

    before_action :ensure_stub_mode

    def create
      claims = TokenVerifier.new.verify(StubIssuer.access_token(fixture))
      sign_in(User.from_claims(claims), sid: claims.sid)

      redirect_to root_path
    end

    private
      def fixture = StubIssuer.identity(params[:email]) || head(:not_found)

      def ensure_stub_mode
        head :not_found unless StubIssuer.available?
      end
  end
end
