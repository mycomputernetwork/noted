# The tiled board (PRD §7.1) and the editor that opens on top of it (§8.2).
#
# Milestone 4 filters the same board by folder and opens the same note in a
# full pane; both reuse the query, the card partial and the editor partial
# below rather than growing a second board or a second editor.
class NotesController < ApplicationController
  before_action :set_note, only: %i[show update destroy]

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

  # Both render the same editor partial into the same turbo frame. `new`
  # builds an unsaved Note: nothing is written until the first keystroke
  # (PRD §8.1), so opening the editor and walking away leaves no trace.
  def new
    @note = notes.new
    @folders = folders.ordered
  end

  def show
    @folders = folders.ordered
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
