module Dev
  class TokensController < ActionController::API
    before_action :ensure_stub_mode

    # Lets a native client in development hold a real bearer token without a
    # running auth service, so the API's verification path is never bypassed.
    def create
      fixture = StubIssuer.identity(params[:email]) or return head(:not_found)
      User.from_claims(TokenVerifier.new.verify(StubIssuer.access_token(fixture)))

      render json: { access_token: StubIssuer.access_token(fixture), token_type: "Bearer", expires_in: 900 }
    end

    private
      def ensure_stub_mode
        head :not_found unless StubIssuer.available?
      end
  end
end
