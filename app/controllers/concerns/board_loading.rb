module BoardLoading
  extend ActiveSupport::Concern

  private
    def load_board(folder: nil)
      @folder = folder
      # with_attached_images avoids two queries per card for the thumbnail strip.
      scope = notes.kept
        .includes(:folder)
        .with_attached_images

      scope = folder ? scope.where(folder_id: folder.id).folder_board_order : scope.board_order

      @pinned, @others = scope.to_a.partition(&:pinned?)
    end
end
