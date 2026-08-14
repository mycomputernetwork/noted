module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :resume_session
    helper_method :current_user, :signed_in?
  end

  # ---------------------------------------------------------------------------
  # MILESTONE 1 STUB.
  #
  # Sign-in arrives in milestone 7. Until then current_user unconditionally
  # returns the seeded development user, so every controller, query and view
  # can be written against real ownership from the first line rather than being
  # retrofitted later.
  #
  # Milestone 7 deletes the two stub methods below and nothing else in this
  # file — resume_session starts looking the session token up in the cookie.
  # ---------------------------------------------------------------------------

  def current_user
    Current.user ||= development_user
  end

  def signed_in? = current_user.present?

  private
    def development_user
      User.order(:id).first ||
        raise(<<~MESSAGE)
          No user exists yet, and sign-in is not built until milestone 7.
          Run `bin/rails db:seed` to create the development user.
        MESSAGE
    end

    def resume_session
      # Milestone 7:
      #   Current.session = Session.live.find_by(id: cookies.signed[:session_id])
      #   Current.session&.touch_activity!
      #   redirect_to sign_in_path unless Current.session
      Current.user = development_user
    end

    def require_authentication
      # Milestone 7 turns this into a real guard.
      true
    end
end
