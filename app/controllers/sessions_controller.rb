class SessionsController < ApplicationController
  layout "plain"

  skip_before_action :require_authentication, only: %i[new create failure]

  def new
    return redirect_to root_path if signed_in?

    @stub_users = StubIssuer.users if AuthService.stubbed?
  end

  def create
    id_token = request.env.dig("omniauth.auth", "credentials", "id_token")
    claims = TokenVerifier.new.verify(id_token)
    sign_in(User.from_claims(claims), sid: claims.sid, id_token: id_token)

    redirect_to root_path
  rescue AuthService::Error
    redirect_to sign_in_path, alert: "Sign-in failed."
  end

  def failure
    redirect_to sign_in_path, alert: "Sign-in failed."
  end

  def destroy
    end_session = AuthService.end_session_url(id_token_hint: current_session&.id_token, redirect_uri: sign_in_url)
    sign_out

    if end_session
      redirect_to end_session, allow_other_host: true
    else
      redirect_to sign_in_path, notice: "Signed out."
    end
  end
end
