module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :current_user, :signed_in? if respond_to?(:helper_method)
  end

  def current_user = Current.user

  def current_session = Current.session

  def signed_in? = current_user.present?

  def sign_in(user, sid: nil)
    Current.session = user.sessions.create!(
      sid: sid, issuer: AuthService.issuer,
      user_agent: request.user_agent, ip_address: request.remote_ip
    )
    Current.user = user
    session[:noted_session] = Current.session.id
  end

  def sign_out
    current_session&.destroy
    reset_session
    Current.session = Current.user = nil
  end

  private
    def resume_session
      Current.session = Session.live.from_current_issuer.find_by(id: session[:noted_session])
      Current.session&.touch_activity!
      Current.user = Current.session&.user
    end

    def require_authentication
      resume_session
      redirect_to sign_in_path unless signed_in?
    end
end
