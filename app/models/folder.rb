class Folder < ApplicationRecord
  include UuidPrimaryKey
  include SyncBroadcast

  belongs_to :user
  has_many :notes, dependent: :nullify

  normalizes :name, with: ->(name) { name.to_s.strip }

  validates :name, presence: true, length: { maximum: 60 }

  before_validation :assign_position, on: :create

  scope :ordered, -> { order(:position, :id) }
  scope :kept, -> { where(deleted_at: nil) }

  def self.delete(id_or_array)
    where(id: id_or_array).find_each { |folder| folder.notes.update_all(folder_board_position: nil) }
    super
  end

  MANAGEABLE_COUNT = 15

  # Call through the owner's relation (user.folders.reorder_to) so an id from
  # another account is a scoped no-op, not a cross-account write.
  def self.reorder_to(ids)
    transaction do
      ids.each_with_index do |id, i|
        folder = find_by(id: id)
        folder&.update!(position: i)
      end
    end
  end

  def move_in_tree(before_id: nil, after_id: nil)
    success = false

    self.class.transaction do
      before_folder = tree_neighbor(before_id)
      after_folder = tree_neighbor(after_id)
      unless valid_tree_reference?(before_id, before_folder) && valid_tree_reference?(after_id, after_folder)
        errors.add(:position, :invalid)
        raise ActiveRecord::Rollback
      end

      list = user.folders.kept.ordered.to_a.reject { |folder| folder.id == id }
      index = tree_insert_index(list, before_folder:, after_folder:)
      list.insert(index, self)

      list.each_with_index { |folder, position| folder.update!(position: position) }
      success = true
    end

    reload if success
    success
  end

  private
    def assign_position
      self.position = (user&.folders&.maximum(:position) || -1) + 1
    end

    def tree_neighbor(id)
      return nil if id.blank?

      user.folders.kept.find_by(id: id)
    end

    def valid_tree_reference?(id, folder)
      id.blank? || (folder && folder.id != self.id)
    end

    def tree_insert_index(folders, before_folder:, after_folder:)
      if before_folder
        folders.index { |folder| folder.id == before_folder.id } || 0
      elsif after_folder
        index = folders.index { |folder| folder.id == after_folder.id }
        index ? index + 1 : folders.length
      else
        0
      end
    end
end
