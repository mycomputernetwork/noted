class Tree
  Branch = Struct.new(:folder, :notes) do
    def empty? = notes.empty?
  end

  attr_reader :branches, :unfiled

  def self.for(user:) = new(user)

  def initialize(user)
    notes = user.notes.for_tree.to_a
    filed = notes.group_by(&:folder_id)

    @branches = user.folders.ordered.map { |folder| Branch.new(folder, filed.fetch(folder.id, [])) }
    @unfiled  = filed.fetch(nil, [])
  end

  # Empty folders still render — they must stay droppable.
  def folders = branches.map(&:folder)

  def note_count = branches.sum { |branch| branch.notes.size } + unfiled.size

  def branch_for(folder) = branches.find { |branch| branch.folder.id == folder&.id }
end
