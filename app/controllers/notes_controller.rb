# The tiled board (PRD §7.1): every kept note, pinned ones first, laid out as
# a masonry grid.
#
# Milestone 3 adds the editor this view links into; milestone 4 filters the
# same board by folder. Both reuse the query and the card partial below rather
# than growing a second board.
class NotesController < ApplicationController
  def index
    @sort = Note::SORTS.key?(params[:sort]) ? params[:sort] : "edited"
    @direction = params[:direction] == "asc" ? "asc" : "desc"

    # Scoped through current_user, always (PRD §5). `with_attached_images`
    # keeps the thumbnail strip from issuing two queries per card.
    scope = notes.kept
      .includes(:folder)
      .with_attached_images
      .sorted(by: @sort, direction: @direction)

    @pinned, @others = scope.to_a.partition(&:pinned?)
  end
end
