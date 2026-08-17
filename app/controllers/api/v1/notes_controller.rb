module Api
  module V1
    class NotesController < BaseController
      before_action :set_note, only: %i[show update destroy]

      def index
        render json: notes.kept.sorted.map { |note| serialize(note) }
      end

      def show
        render json: serialize(@note)
      end

      def create
        note = notes.new(note_params)

        if note.save
          render json: serialize(note), status: :created
        else
          render_errors(note)
        end
      end

      def update
        if @note.update(note_params)
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

        def note_params
          permitted = params.require(:note).permit(:id, :title, :body, :folder_id, :pinned, :position)
          permitted[:folder_id] = permitted[:folder_id].presence if permitted.key?(:folder_id)
          permitted
        end

        def serialize(note)
          NoteSerializer.new(note, view_context: self).as_json
        end
    end
  end
end
