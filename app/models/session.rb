class Session < ApplicationRecord
  include UuidPrimaryKey

  LIFETIME = 30.days

  belongs_to :user

  before_validation { self.last_active_at ||= Time.current }

  scope :live, -> { where(last_active_at: LIFETIME.ago..) }
  scope :expired, -> { where(last_active_at: ...LIFETIME.ago) }

  def expired? = last_active_at < LIFETIME.ago

  # Only written when stale enough to matter — writing on every request means a
  # SQLite lock.
  def touch_activity!(threshold: 1.hour)
    return if last_active_at > threshold.ago

    update_column(:last_active_at, Time.current)
  end
end
