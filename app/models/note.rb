class Note < ApplicationRecord
  include UuidPrimaryKey
  include SyncBroadcast

  belongs_to :user
  belongs_to :folder, optional: true

  has_many_attached :images

  before_validation :assign_board_position, on: :create
  before_validation :assign_folder_board_position, on: :create

  validate :folder_must_belong_to_same_user

  # --- Lifecycle scopes ----------------------------------------------------
  scope :kept,     -> { where(archived_at: nil, deleted_at: nil) }
  scope :archived, -> { where(deleted_at: nil).where.not(archived_at: nil) }
  scope :trashed,  -> { where.not(deleted_at: nil) }

  # --- Ordering ------------------------------------------------------------
  scope :board_order, -> {
    order(pinned: :desc)
      .order(Arel.sql("notes.board_position IS NULL, notes.board_position ASC"))
      .order(updated_at: :desc, id: :desc)
  }
  scope :folder_board_order, -> {
    order(pinned: :desc)
      .order(Arel.sql("COALESCE(notes.folder_board_position, notes.board_position) IS NULL"))
      .order(Arel.sql("COALESCE(notes.folder_board_position, notes.board_position) ASC"))
      .order(updated_at: :desc, id: :desc)
  }

  # Positioned notes first (nulls last), then by the label the tree draws.
  scope :tree_order, -> {
    order(Arel.sql("notes.position IS NULL, notes.position ASC"))
      .order(Arel.sql("LOWER(COALESCE(NULLIF(notes.title, ''), notes.body))"))
      .order(:id)
  }
  scope :for_tree, -> { kept.select(:id, :title, :body, :folder_id, :position).tree_order }

  def self.reorder_board(ids, folder_id: nil)
    ids = ids.map(&:to_s).uniq
    return false if ids.empty?

    folder_id.present? ? reorder_folder_board(ids, folder_id) : reorder_all_board(ids)
  end

  def self.reorder_all_board(ids)
    transaction do
      current = kept.board_order.to_a
      return false unless current.map(&:id).sort == ids.sort

      by_id = current.index_by(&:id)
      ids.map { |id| by_id.fetch(id) }.each_with_index do |note, position|
        note.update!(board_position: position) unless note.board_position == position
      end
    end

    true
  end

  def self.reorder_folder_board(ids, folder_id)
    transaction do
      current = kept.where(folder_id: folder_id).folder_board_order.to_a
      return false unless current.map(&:id).sort == ids.sort

      by_id = current.index_by(&:id)
      ids.map { |id| by_id.fetch(id) }.each_with_index do |note, position|
        note.update!(folder_board_position: position) unless note.folder_board_position == position
      end
    end

    true
  end

  # --- State ---------------------------------------------------------------
  def archived? = archived_at.present?
  def trashed?  = deleted_at.present?

  def archive!   = update!(archived_at: Time.current)
  def unarchive! = update!(archived_at: nil)

  def trash!   = update!(deleted_at: Time.current, archived_at: nil)
  def restore! = update!(deleted_at: nil)

  def empty?
    title.blank? && body.blank? && !images.attached?
  end

  def tree_label
    title.presence || body.to_s.lines.first&.strip.presence || "Untitled"
  end

  def preview(lines: 12)
    body.to_s.lines.first(lines).join.strip
  end

  def move_in_tree(folder_id:, before_id: nil, after_id: nil)
    destination_folder_id = folder_id.presence
    success = false

    self.class.transaction do
      unless valid_tree_folder?(destination_folder_id)
        errors.add(:folder, :invalid_owner)
        raise ActiveRecord::Rollback
      end

      before_note = tree_neighbor(before_id)
      after_note = tree_neighbor(after_id)
      unless valid_tree_reference?(before_id, before_note, destination_folder_id) && valid_tree_reference?(after_id, after_note, destination_folder_id)
        errors.add(:position, :invalid)
        raise ActiveRecord::Rollback
      end

      source_folder_id = self.folder_id
      same_list = same_tree_list?(source_folder_id, destination_folder_id)
      folder_board_position = board_position_for_folder(destination_folder_id) unless same_list
      source = tree_list(source_folder_id)
      destination = same_list ? source : tree_list(destination_folder_id)

      source.reject! { |note| note.id == id }
      destination.reject! { |note| note.id == id }

      index = tree_insert_index(destination, before_note:, after_note:)
      destination.insert(index, self)

      rewrite_tree_list(source, source_folder_id) unless same_list
      rewrite_tree_list(destination, destination_folder_id)
      update!(folder_board_position: folder_board_position) unless same_list
      success = true
    end

    reload if success
    success
  end

  private
    def tree_list(folder_id)
      user.notes.kept.where(folder_id: folder_id).tree_order.to_a
    end

    def valid_tree_folder?(folder_id)
      folder_id.nil? || user.folders.kept.exists?(id: folder_id)
    end

    def tree_neighbor(id)
      return nil if id.blank?

      user.notes.kept.find_by(id: id)
    end

    def valid_tree_reference?(id, note, folder_id)
      id.blank? || (note && note.id != self.id && same_tree_list?(note.folder_id, folder_id))
    end

    def tree_insert_index(notes, before_note:, after_note:)
      if before_note
        notes.index { |note| note.id == before_note.id } || 0
      elsif after_note
        index = notes.index { |note| note.id == after_note.id }
        index ? index + 1 : notes.length
      else
        0
      end
    end

    def rewrite_tree_list(notes, folder_id)
      notes.each_with_index do |note, position|
        note.update!(folder_id: folder_id, position: position)
      end
    end

    def same_tree_list?(left, right)
      left.presence == right.presence
    end

    def assign_board_position
      return if board_position.present? || user.nil?

      self.board_position = (user.notes.kept.minimum(:board_position) || 0) - 1
    end

    def assign_folder_board_position
      return if folder_board_position.present? || user.nil? || folder_id.blank?

      self.folder_board_position = board_position_for_folder(folder_id)
    end

    def board_position_for_folder(folder_id)
      return nil if folder_id.blank?

      current_min = user.notes.kept
        .where(folder_id: folder_id)
        .where.not(id: id)
        .pick(Arel.sql("MIN(COALESCE(folder_board_position, board_position))"))
      (current_min || 0) - 1
    end

    # folder_id arrives from the client, so a note could be filed into another
    # account's folder — the one cross-account leak path.
    def folder_must_belong_to_same_user
      return if folder.nil? || folder.user_id == user_id

      errors.add(:folder, :invalid_owner)
    end
end
