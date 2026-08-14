module NotesHelper
  # Sort and direction are URL state, not session state: a board is then
  # linkable and the back button behaves. Each control rebuilds the whole
  # query string so neither dimension clobbers the other.
  # url_for rather than root_path: the folder board is the same board (§7.3)
  # and has to keep its sort, so the control rebuilds the URL it is on rather
  # than naming the one it assumes it is on.
  def sort_option_path(key)
    url_for(sort: key, direction: @direction, only_path: true)
  end

  def sort_direction_path
    url_for(sort: @sort, direction: @direction == "asc" ? "desc" : "asc", only_path: true)
  end

  def sort_direction_label
    @direction == "asc" ? "Oldest first" : "Newest first"
  end

  # Back from the full pane goes to whatever board was underneath (§7.7):
  # the folder's board if the note is filed, otherwise all notes.
  def pane_back_path(note)
    note.folder ? folder_path(note.folder) : root_path
  end

  # The board sorts by one timestamp at a time; showing the other one on the
  # card would just be a number that does not match the order the eye sees.
  def card_timestamp(note)
    stamp = @sort == "created" ? note.created_at : note.updated_at
    tag.time(time_ago_in_words(stamp), datetime: stamp.iso8601,
      title: l(stamp, format: :long), class: "card__time")
  end
end
