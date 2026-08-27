module Api
  module V1
    class BaseController < ActionController::API
      include BearerAuthentication
      include Scoped

      rescue_from ActiveRecord::RecordNotFound, with: :not_found

      private
        # An id belonging to another account is reported as missing rather than
        # forbidden, so the API never confirms that it exists.
        def not_found
          render json: { errors: [ "Not found" ] }, status: :not_found
        end

        def render_errors(record)
          render json: { errors: record.errors.full_messages }, status: :unprocessable_content
        end
    end
  end
end
