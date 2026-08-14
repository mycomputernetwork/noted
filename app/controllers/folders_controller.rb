# Folders (PRD §5) and the board filtered to one of them (§7.3).
#
# `show` renders the board partial rather than a folder-shaped view of its
# own: a folder board that looked different from the board would be a second
# board to maintain, and the only difference between them is a `where`.
#
# Create, rename and delete all happen in the sidebar, and all three answer
# with a redirect to a full page rather than into the row's frame. The tree,
# the board and the folder select in every open editor all move when a folder
# does, and none of them is inside that frame.
class FoldersController < ApplicationController
  include BoardLoading

  before_action :set_folder, only: %i[show edit update destroy]

  def show
    load_board(folder: @folder)
    render "notes/index"
  end

  # The row, swapped for a form, in place in the tree.
  def edit
  end

  def create
    folder = folders.new(folder_params)

    if folder.save
      redirect_back_or_to folder_path(folder)
    else
      redirect_back_or_to root_path, alert: folder.errors.full_messages.to_sentence
    end
  end

  def update
    if @folder.update(folder_params)
      redirect_back_or_to folder_path(@folder)
    else
      redirect_back_or_to root_path, alert: @folder.errors.full_messages.to_sentence
    end
  end

  # The notes survive and become unfiled (PRD §11) — `dependent: :nullify` on
  # the association. Deleting a folder is not a way to delete notes, and there
  # is deliberately no way to make it one.
  def destroy
    @folder.destroy
    redirect_to root_path
  end

  private
    # folders.find, never Folder.find (PRD §5).
    def set_folder
      @folder = folders.find(params[:id])
    end

    def folder_params
      params.require(:folder).permit(:name)
    end
end
