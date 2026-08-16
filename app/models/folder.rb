class Folder < ApplicationRecord
  include UuidPrimaryKey

  belongs_to :user

  # Deleting a folder does not delete its notes; they become unfiled.
  has_many :notes, dependent: :nullify

  normalizes :name, with: ->(name) { name.to_s.strip }

  validates :name, presence: true, length: { maximum: 60 }

  before_validation :assign_position, on: :create

  scope :ordered, -> { order(:position, :id) }

  # Folders are flat by design. Revisit only if a user's flat list exceeds
  # roughly 15 entries in practice.
  MANAGEABLE_COUNT = 15

  # Always call through the owner's relation — `user.folders.reorder_to(ids)` —
  # so the `where` below is scoped and an id from another account is a no-op
  # rather than a cross-account write.
  def self.reorder_to(ids)
    transaction do
      ids.each_with_index { |id, i| where(id: id).update_all(position: i) }
    end
  end

  private
    def assign_position
      self.position = (user&.folders&.maximum(:position) || -1) + 1
    end
end
