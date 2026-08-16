module BoardLoading
  extend ActiveSupport::Concern

  private
    def load_board(folder: nil)
      @folder = folder
      @sort = Note::SORTS.key?(params[:sort]) ? params[:sort] : "edited"
      @direction = params[:direction] == "asc" ? "asc" : "desc"

      # with_attached_images avoids two queries per card for the thumbnail strip.
      scope = notes.kept
        .includes(:folder)
        .with_attached_images
        .sorted(by: @sort, direction: @direction)

      scope = scope.where(folder_id: folder.id) if folder

      @pinned, @others = scope.to_a.partition(&:pinned?)
    end
end
