class NotesController < ApplicationController
  include BoardLoading

  before_action :set_note, only: %i[show update destroy]

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

  def create
    @note = notes.new(note_params)

    if @note.save
      render json: note_json(@note), status: :created
    else
      render json: { errors: @note.errors.full_messages }, status: :unprocessable_content
    end
  end

  def update
    if @note.update(note_params)
      render json: note_json(@note)
    else
      render json: { errors: @note.errors.full_messages }, status: :unprocessable_content
    end
  end

  # Discard, not delete: refuses a note with content, so an autosave bug can
  # cost a keystroke but never a note. Trashing is milestone 8, via deleted_at.
  def destroy
    return head :unprocessable_content unless @note.empty?

    @note.destroy
    head :no_content
  end

  private
    def set_note
      @note = notes.kept.find(params[:id])
    end

    def note_params
      permitted = params.require(:note).permit(:title, :body, :folder_id, :pinned)
      permitted[:folder_id] = permitted[:folder_id].presence if permitted.key?(:folder_id)
      permitted
    end

    def note_json(note)
      {
        id: note.id,
        url: note_path(note),
        empty: note.empty?,
        updated_at: note.updated_at.iso8601
      }
    end
end
