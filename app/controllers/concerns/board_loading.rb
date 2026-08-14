# The tiled board (PRD §7.1) and the folder board (§7.3) are the same view
# over the same query, so they are the same code. A folder board is the board
# with one `where` on it — anything more than that and the two would start
# drifting apart.
module BoardLoading
  extend ActiveSupport::Concern

  private
    def load_board(folder: nil)
      @folder = folder
      @sort = Note::SORTS.key?(params[:sort]) ? params[:sort] : "edited"
      @direction = params[:direction] == "asc" ? "asc" : "desc"

      # Scoped through current_user, always (PRD §5). `with_attached_images`
      # keeps the thumbnail strip from issuing two queries per card.
      scope = notes.kept
        .includes(:folder)
        .with_attached_images
        .sorted(by: @sort, direction: @direction)

      scope = scope.where(folder_id: folder.id) if folder

      @pinned, @others = scope.to_a.partition(&:pinned?)
    end
end
