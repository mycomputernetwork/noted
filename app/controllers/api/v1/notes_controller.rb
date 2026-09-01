module Api
  module V1
    class NotesController < BaseController
      before_action :set_note, only: %i[show update destroy]

      def index
        render json: notes.kept.board_order.map { |note| serialize(note) }
      end

      def reorder
        folder_id = params[:folder_id].presence
        return render_errors_for("Folder is invalid") if folder_id && !folders.kept.exists?(id: folder_id)

        if notes.reorder_board(Array(params.require(:note_ids)), folder_id: folder_id)
          render json: notes.kept.board_order.map { |note| serialize(note) }
        else
          render_errors_for("Note order is invalid")
        end
      end

      def show
        render json: serialize(@note)
      end

      def create
        note = notes.new(create_params)

        if note.save
          render json: serialize(note), status: :created
        else
          render_errors(note)
        end
      end

      def update
        if tree_move?
          if update_with_tree_move
            render json: serialize(@note)
          else
            render_errors(@note)
          end
        elsif @note.update(note_params)
          render json: serialize(@note)
        else
          render_errors(@note)
        end
      end

      def destroy
        return render json: { errors: ["Note is not empty"] }, status: :unprocessable_content unless @note.empty?

        @note.destroy
        head :no_content
      end

      private
        def set_note
          @note = notes.kept.find(params[:id])
        end

        def create_params
          params.require(:note).permit(:id, :title, :body, :folder_id, :pinned, :board_position).tap do |permitted|
            permitted[:folder_id] = permitted[:folder_id].presence if permitted.key?(:folder_id)
          end
        end

        def note_params
          params.require(:note).permit(:title, :body, :folder_id, :pinned, :board_position).tap do |permitted|
            permitted[:folder_id] = permitted[:folder_id].presence if permitted.key?(:folder_id)
          end
        end

        def tree_params
          params.require(:note).permit(:folder_id, :before_id, :after_id).tap do |permitted|
            permitted[:folder_id] = permitted[:folder_id].presence if permitted.key?(:folder_id)
          end
        end

        def tree_move?
          body = params.require(:note)
          return true if body.key?(:before_id) || body.key?(:after_id)
          return false unless body.key?(:folder_id)

          body[:folder_id].presence != @note.folder_id
        end

        def update_with_tree_move
          success = false

          Note.transaction do
            unless @note.update(note_params.except(:folder_id))
              raise ActiveRecord::Rollback
            end

            move = tree_params
            move[:folder_id] = @note.folder_id if move[:folder_id].nil? && !params.require(:note).key?(:folder_id)

            unless @note.move_in_tree(**move.to_h.symbolize_keys)
              raise ActiveRecord::Rollback
            end

            success = true
          end

          success
        end

        def render_errors_for(message)
          render json: { errors: [message] }, status: :unprocessable_content
        end

        def serialize(note)
          NoteSerializer.new(note, view_context: self).as_json
        end
    end
  end
end
