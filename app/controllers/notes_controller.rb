# The tiled board (PRD §7.1) and the editor that opens on top of it (§8.2).
#
# Milestone 4 filters the same board by folder and opens the same note in a
# full pane; both reuse the query, the card partial and the editor partial
# below rather than growing a second board or a second editor.
class NotesController < ApplicationController
  include BoardLoading

  before_action :set_note, only: %i[show update destroy]

  def index
    load_board
  end

  # `new` builds an unsaved Note: nothing is written until the first
  # keystroke (PRD §8.1), so opening the composer and walking away leaves no
  # trace. Opened from a folder board, the note starts in that folder — the
  # board you are looking at is the answer to "where should this go".
  def new
    @note = notes.new(folder_id: params[:folder_id].presence)
    @folders = folders.ordered
  end

  # One URL, two surfaces (PRD §7.7, §8.4). A card asks for this note into
  # the board's editor frame and gets the modal; the sidebar links to it
  # plainly and gets the full pane. The rule is where you clicked, and the
  # frame header is exactly the record of that — so a note stays linkable and
  # the back button keeps working either way.
  def show
    @folders = folders.ordered

    render :pane unless turbo_frame_request_id == "editor"
  end

  # Called by the autosave controller on the first keystroke, never by a form
  # submission.
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

  # Discard, not delete. This exists for exactly one case: a note created on
  # the first keystroke and then emptied out again before the editor closed.
  # Refusing anything with content in it means an autosave bug can lose a
  # keystroke at worst, never a note (PRD §8.1: no interaction may lose data).
  # Trashing a note the user still wants gone is milestone 8's job and goes
  # through `deleted_at`, not through here.
  def destroy
    return head :unprocessable_content unless @note.empty?

    @note.destroy
    head :no_content
  end

  private
    # notes.find, never Note.find: an id belonging to another account has to
    # miss rather than load (PRD §5).
    def set_note
      @note = notes.kept.find(params[:id])
    end

    def note_params
      permitted = params.require(:note).permit(:title, :body, :folder_id, :pinned)
      permitted[:folder_id] = permitted[:folder_id].presence if permitted.key?(:folder_id)
      permitted
    end

    # The autosave controller needs three things back: where to send the next
    # save, whether the record still counts as empty, and a timestamp to show.
    def note_json(note)
      {
        id: note.id,
        url: note_path(note),
        empty: note.empty?,
        updated_at: note.updated_at.iso8601
      }
    end
end
