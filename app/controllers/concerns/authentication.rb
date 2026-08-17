module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :resume_session
    helper_method :current_user, :signed_in? if respond_to?(:helper_method)
  end

  # Stub until sign-in (milestone 7): current_user is the seeded user, so the
  # whole app is written against real ownership now. Milestone 7 replaces the
  # two stubs below with a real session lookup.
  def current_user
    Current.user ||= development_user
  end

  def signed_in? = current_user.present?

  private
    def development_user
      User.order(:created_at).first ||
        raise(<<~MESSAGE)
          No user exists yet, and sign-in is not built until milestone 7.
          Run `bin/rails db:seed` to create the development user.
        MESSAGE
    end

    def resume_session
      Current.user = development_user
    end

    def require_authentication
      true
    end
end
