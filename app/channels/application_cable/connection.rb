module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_user
    end

    private
      def find_user
        user_from_token || user_from_session || reject_unauthorized_connection
      end

      def user_from_token
        token = bearer_token or return

        claims = TokenVerifier.new.verify(token)
        User.find_by(auth_sub: claims.subject)
      rescue AuthService::Error
        nil
      end

      def user_from_session
        noted_session = Session.live.from_current_issuer.find_by(id: request.session[:noted_session])
        noted_session&.touch_activity!
        noted_session&.user
      end

      def bearer_token
        scheme, token = request.authorization.to_s.split(" ", 2)
        token if scheme&.casecmp("bearer")&.zero?
      end
  end
end
