class Folder < ApplicationRecord
  include UuidPrimaryKey

  belongs_to :user
  has_many :notes, dependent: :nullify

  normalizes :name, with: ->(name) { name.to_s.strip }

  validates :name, presence: true, length: { maximum: 60 }

  before_validation :assign_position, on: :create

  scope :ordered, -> { order(:position, :id) }

  MANAGEABLE_COUNT = 15

  # Call through the owner's relation (user.folders.reorder_to) so an id from
  # another account is a scoped no-op, not a cross-account write.
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
