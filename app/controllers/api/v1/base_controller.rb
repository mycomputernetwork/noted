module Api
  module V1
    class BaseController < ActionController::API
      include Authentication
      include Scoped

      rescue_from ActiveRecord::RecordNotFound, with: :not_found

      private
        def not_found
          head :not_found
        end

        def render_errors(record)
          render json: { errors: record.errors.full_messages }, status: :unprocessable_content
        end
    end
  end
end
