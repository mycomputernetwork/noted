module NotesHelper
  def sort_option_path(key)
    url_for(sort: key, direction: @direction, only_path: true)
  end

  def sort_direction_path
    url_for(sort: @sort, direction: @direction == "asc" ? "desc" : "asc", only_path: true)
  end

  def sort_direction_label
    @direction == "asc" ? "Oldest first" : "Newest first"
  end

  def pane_back_path(note)
    note.folder ? folder_path(note.folder) : root_path
  end

  def card_timestamp(note)
    stamp = @sort == "created" ? note.created_at : note.updated_at
    tag.time(time_ago_in_words(stamp), datetime: stamp.iso8601,
      title: l(stamp, format: :long), class: "card__time")
  end
end
