# The sidebar tree (PRD §7.6) — folders, the notes inside them, and the
# unfiled notes that sit at the root below them.
#
# A plain object rather than a query per row. The tree is rendered on every
# page in the application, so it gets exactly two queries: folders, then every
# live note, grouped in Ruby. At the expected scale (§4) the whole tree is a
# few hundred rows of text, which is cheaper to send once than to round-trip
# on every disclosure triangle — which is also why nothing here is lazy.
#
# Only the columns the tree draws are selected. A note's body is loaded
# because an untitled note is labelled by its first line, but nothing else
# about a note reaches the sidebar.
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

  # Every folder renders, including the empty ones: a folder that vanishes
  # when its last note is filed elsewhere is a folder you cannot drop onto.
  def folders = branches.map(&:folder)

  def note_count = branches.sum { |branch| branch.notes.size } + unfiled.size

  def branch_for(folder) = branches.find { |branch| branch.folder.id == folder&.id }
end
