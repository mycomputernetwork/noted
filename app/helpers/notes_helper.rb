module NotesHelper
  def pane_back_path(note)
    note.folder ? folder_path(note.folder) : root_path
  end

  def card_timestamp(note)
    tag.time(time_ago_in_words(note.updated_at), datetime: note.updated_at.iso8601,
      title: l(note.updated_at, format: :long), class: "card__time")
  end
end
