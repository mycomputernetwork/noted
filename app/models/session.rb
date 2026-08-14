class Session < ApplicationRecord
  LIFETIME = 30.days

  belongs_to :user

  before_validation { self.last_active_at ||= Time.current }

  scope :live, -> { where(last_active_at: LIFETIME.ago..) }
  scope :expired, -> { where(last_active_at: ...LIFETIME.ago) }

  def expired? = last_active_at < LIFETIME.ago

  # Sliding expiry. Called once per request by the Authentication concern, but
  # only written when the value is stale enough to matter — otherwise every
  # page view is a write, which on SQLite means a lock.
  def touch_activity!(threshold: 1.hour)
    return if last_active_at > threshold.ago

    update_column(:last_active_at, Time.current)
  end
end
