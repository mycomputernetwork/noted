class SessionsController < ApplicationController
  layout "plain"

  skip_before_action :require_authentication, only: %i[new create failure]

  def new
    return redirect_to root_path if signed_in?

    @stub_users = StubIssuer.users if AuthService.stubbed?
  end

  def create
    claims = TokenVerifier.new.verify(request.env.dig("omniauth.auth", "credentials", "id_token"))
    sign_in(User.from_claims(claims), sid: claims.sid)

    redirect_to root_path
  rescue AuthService::Error
    redirect_to sign_in_path, alert: "Sign-in failed."
  end

  def failure
    redirect_to sign_in_path, alert: "Sign-in failed."
  end

  def destroy
    sign_out
    redirect_to sign_in_path, notice: "Signed out."
  end
end
