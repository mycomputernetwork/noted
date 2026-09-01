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
        folder = folders.new(create_params)

        if folder.save
          render json: serialize(folder), status: :created
        else
          render_errors(folder)
        end
      end

      def update
        if tree_move?
          if update_with_tree_move
            render json: serialize(@folder)
          else
            render_errors(@folder)
          end
        elsif @folder.update(folder_params)
          render json: serialize(@folder)
        else
          render_errors(@folder)
        end
      end

      def destroy
        @folder.notes.update_all(folder_id: nil, folder_board_position: nil)
        @folder.update!(deleted_at: Time.current)
        head :no_content
      end

      private
        def set_folder
          @folder = folders.kept.find(params[:id])
        end

        def create_params
          params.require(:folder).permit(:id, :name)
        end

        def folder_params
          params.require(:folder).permit(:name)
        end

        def tree_params
          params.require(:folder).permit(:before_id, :after_id)
        end

        def tree_move?
          body = params.require(:folder)
          body.key?(:before_id) || body.key?(:after_id)
        end

        def update_with_tree_move
          success = false

          Folder.transaction do
            unless @folder.update(folder_params)
              raise ActiveRecord::Rollback
            end

            unless @folder.move_in_tree(**tree_params.to_h.symbolize_keys)
              raise ActiveRecord::Rollback
            end

            success = true
          end

          success
        end

        def serialize(folder)
          FolderSerializer.new(folder).as_json
        end
    end
  end
end
