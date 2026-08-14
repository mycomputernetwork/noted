# `position` orders the sidebar tree and nothing else (PRD §5). The board goes
# on sorting by edited or created, because a hand-arranged board stops
# answering "what did I touch recently", which is the question it exists to
# answer.
#
# The column ships with the tree even though dragging to reorder is milestone
# 13: adding it now is an empty migration, and adding it later is a migration
# against a populated table. Nullable on purpose — null means "not yet placed
# by hand", which is every note until someone drags one.
class AddPositionToNotes < ActiveRecord::Migration[8.1]
  def change
    add_column :notes, :position, :integer

    add_index :notes, [ :user_id, :folder_id, :position ],
      name: "index_notes_on_tree_order"
  end
end
