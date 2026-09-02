module SyncOrigin
  extend ActiveSupport::Concern

  included do
    before_action :record_sync_client
  end

  private
    def record_sync_client
      Current.client = request.headers["X-Client-Id"].presence
    end
end
