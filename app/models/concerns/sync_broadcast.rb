module SyncBroadcast
  extend ActiveSupport::Concern

  included do
    after_commit :broadcast_sync
  end

  private
    def broadcast_sync
      ::SyncChannel.broadcast_to(user, { type: self.class.name.downcase, id: id })
    end
end
