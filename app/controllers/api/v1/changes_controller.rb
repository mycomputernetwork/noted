module Api
  module V1
    class ChangesController < BaseController
      def index
        since = parse_cursor(params[:cursor])
        now = Time.current

        render json: {
          notes: changed(notes, since).map { |n| NoteSerializer.new(n, view_context: self).as_json },
          folders: changed(folders, since).map { |f| FolderSerializer.new(f).as_json },
          cursor: now.utc.iso8601
        }
      end

      private
        def changed(scope, since)
          since ? scope.where("updated_at > ?", since) : scope.all
        end

        def parse_cursor(value)
          Time.iso8601(value) if value.present?
        rescue ArgumentError
          nil
        end
    end
  end
end
