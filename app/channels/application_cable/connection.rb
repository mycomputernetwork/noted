module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_user
    end

    private
      # Stub until milestone 7: same single-seed user as Authentication concern.
      def find_user
        User.order(:created_at).first || reject_unauthorized_connection
      end
  end
end
