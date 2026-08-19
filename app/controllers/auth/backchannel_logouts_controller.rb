module Auth
  class BackchannelLogoutsController < ActionController::API
    def create
      claims = LogoutToken.verify(params.require(:logout_token))
      Session.where(sid: claims.sid).destroy_all

      head :ok
    rescue AuthService::Error, ActionController::ParameterMissing
      head :bad_request
    end
  end
end
