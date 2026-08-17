class NotesController < ApplicationController
  include BoardLoading

  before_action :set_note, only: %i[show]

  def index
    load_board
  end

  def new
    @note = notes.new(folder_id: params[:folder_id].presence)
    @folders = folders.ordered
  end

  # A card asks for the modal (Turbo-Frame: editor); a sidebar link gets the
  # full pane. The frame header is the only tell for which.
  def show
    @folders = folders.ordered

    render :pane unless turbo_frame_request_id == "editor"
  end


  private
    def set_note
      @note = notes.kept.find(params[:id])
    end

end
