class NoteSerializer
  def initialize(note, view_context: nil)
    @note = note
    @view_context = view_context
  end

  def as_json(*)
    {
      id: note.id,
      title: note.title,
      body: note.body,
      folder_id: note.folder_id,
      pinned: note.pinned,
      position: note.position,
      board_position: note.board_position,
      folder_board_position: note.folder_board_position,
      empty: note.empty?,
      archived_at: timestamp(note.archived_at),
      deleted_at: timestamp(note.deleted_at),
      created_at: timestamp(note.created_at),
      updated_at: timestamp(note.updated_at),
      url: api_url,
      html_url: html_url,
      images: []
    }
  end

  private
    attr_reader :note, :view_context

    def timestamp(value)
      value&.utc&.iso8601
    end

    def api_url
      view_context.api_v1_note_path(note) if view_context
    end

    def html_url
      view_context.note_path(note) if view_context
    end
end
