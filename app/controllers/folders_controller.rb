class FoldersController < ApplicationController
  include BoardLoading

  before_action :set_folder, only: %i[show edit update destroy]

  def show
    load_board(folder: @folder)
    render "notes/index"
  end

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

  def destroy
    @folder.transaction do
      @folder.unfile_notes!
      @folder.update!(deleted_at: Time.current)
    end
    redirect_to root_path
  end

  private
    def set_folder
      @folder = folders.kept.find(params[:id])
    end

    def folder_params
      params.require(:folder).permit(:name)
    end
end
