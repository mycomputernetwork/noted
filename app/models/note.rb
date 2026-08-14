class Note < ApplicationRecord
  belongs_to :user
  belongs_to :folder, optional: true

  has_many_attached :images

  validate :folder_must_belong_to_same_user

  # --- Lifecycle scopes ----------------------------------------------------
  scope :kept,     -> { where(archived_at: nil, deleted_at: nil) }
  scope :archived, -> { where(deleted_at: nil).where.not(archived_at: nil) }
  scope :trashed,  -> { where.not(deleted_at: nil) }

  # --- Ordering ------------------------------------------------------------
  # Pinned notes sort above the rest, matching Keep's PINNED / OTHERS split.
  scope :by_edited,  ->(dir = :desc) { order(pinned: :desc, updated_at: dir, id: dir) }
  scope :by_created, ->(dir = :desc) { order(pinned: :desc, created_at: dir, id: dir) }

  SORTS = {
    "edited"  => :by_edited,
    "created" => :by_created
  }.freeze

  def self.sorted(by: "edited", direction: "desc")
    dir = direction.to_s == "asc" ? :asc : :desc
    public_send(SORTS.fetch(by.to_s, :by_edited), dir)
  end

  # --- State ---------------------------------------------------------------
  def archived? = archived_at.present?
  def trashed?  = deleted_at.present?

  def archive!   = update!(archived_at: Time.current)
  def unarchive! = update!(archived_at: nil)

  # Soft delete. Purged 30 days later by PurgeTrashedNotesJob.
  def trash!   = update!(deleted_at: Time.current, archived_at: nil)
  def restore! = update!(deleted_at: nil)

  # A note created on first keystroke and then abandoned without any content
  # should not survive the editor closing.
  def empty?
    title.blank? && body.blank? && !images.attached?
  end

  def preview(lines: 12)
    body.to_s.lines.first(lines).join.strip
  end

  private
    # The only way a note can leak across accounts is by being filed into
    # another user's folder, since folder_id arrives from the client. Every
    # other path is already scoped through current_user.
    def folder_must_belong_to_same_user
      return if folder.nil? || folder.user_id == user_id

      errors.add(:folder, :invalid_owner)
    end
end
