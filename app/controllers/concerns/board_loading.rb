module BoardLoading
  extend ActiveSupport::Concern

  private
    def load_board(folder: nil)
      @folder = folder
      @folders = folders.kept.ordered
      load_calendar
      # with_attached_images avoids two queries per card for the thumbnail strip.
      scope = notes.kept
        .includes(:folder)
        .with_attached_images

      scope = folder ? scope.where(folder_id: folder.id).folder_board_order : scope.board_order

      @pinned, @others = scope.to_a.partition(&:pinned?)
      @modal_note = notes.kept.find(params[:note].to_s) if params[:note].present?
    end

    def load_calendar
      year = Integer(params[:calendar_year], exception: false)
      year = Date.current.year unless year&.between?(1900, 2200)

      @calendar_year = year
      @calendar_years = (year_docs.pluck(:year) + [ Date.current.year, Date.current.year + 1, year ]).uniq.sort.reverse
      @year_doc = year_docs.find_by(year: year) || year_docs.new(year: year)
    end
end
