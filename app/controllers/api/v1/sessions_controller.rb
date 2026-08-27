module Api
  module V1
    # The way in for an identity noted has no account for yet. Takes the ID
    # token because the access token carries no email to create one from.
    class SessionsController < ActionController::API
      include BearerAuthentication

      skip_before_action :require_authentication

      def create
        claims = TokenVerifier.new.verify(bearer_token.to_s)

        render json: UserSerializer.new(User.from_claims(claims)).as_json
      rescue AuthService::Error, ActiveRecord::RecordInvalid
        unauthorized
      end
    end
  end
end
