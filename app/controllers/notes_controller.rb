class NotesController < ApplicationController
  include BoardLoading

  before_action :set_note, only: %i[show]

  def index
    load_board
  end

  def new
    @note = notes.new(folder_id: params[:folder_id].presence)
    @folders = folders.kept.ordered
  end

  def show
    @folders = folders.kept.ordered
    render :pane
  end


  private
    def set_note
      @note = notes.kept.find(params[:id])
    end

end
