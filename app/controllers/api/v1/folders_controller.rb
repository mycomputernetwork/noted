module Api
  module V1
    class FoldersController < BaseController
      before_action :set_folder, only: %i[show update destroy]

      def index
        render json: folders.kept.ordered.map { |folder| serialize(folder) }
      end

      def show
        render json: serialize(@folder)
      end

      def create
        folder = folders.new(folder_params)

        if folder.save
          render json: serialize(folder), status: :created
        else
          render_errors(folder)
        end
      end

      def update
        if @folder.update(folder_params)
          render json: serialize(@folder)
        else
          render_errors(@folder)
        end
      end

      def destroy
        @folder.notes.update_all(folder_id: nil)
        @folder.update!(deleted_at: Time.current)
        head :no_content
      end

      private
        def set_folder
          @folder = folders.kept.find(params[:id])
        end

        def folder_params
          params.require(:folder).permit(:id, :name, :position)
        end

        def serialize(folder)
          FolderSerializer.new(folder).as_json
        end
    end
  end
end
