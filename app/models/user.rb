class User < ApplicationRecord
  has_secure_password

  has_many :sessions, dependent: :destroy
  has_many :notes, dependent: :destroy
  has_many :folders, dependent: :destroy
  has_many :day_entries, dependent: :destroy
  has_many :day_logs, dependent: :destroy

  normalizes :email, with: ->(email) { email.to_s.strip.downcase }
  normalizes :name, with: ->(name) { name.to_s.strip.presence }

  validates :email,
    presence: true,
    uniqueness: { case_sensitive: false },
    format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }

  # allow_nil so updating a name doesn't demand the password be resupplied.
  validates :password, length: { minimum: 8 }, allow_nil: true

  def verified? = verified_at.present?

  # Total bytes of every image attached to this user's notes.
  #
  # Computed on demand rather than denormalised onto a counter column: at the
  # expected scale (low hundreds of images) a scoped SUM is trivial, whereas a
  # counter needs maintaining on every attach, purge and note deletion. This
  # figure is visibility only — there are no quotas and nothing is enforced.
  def storage_bytes
    ActiveStorage::Blob
      .joins(:attachments)
      .where(active_storage_attachments: { record_type: "Note", record_id: notes.select(:id) })
      .sum(:byte_size)
  end
end
