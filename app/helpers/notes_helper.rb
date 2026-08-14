module NotesHelper
  # Sort and direction are URL state, not session state: a board is then
  # linkable and the back button behaves. Each control rebuilds the whole
  # query string so neither dimension clobbers the other.
  def sort_option_path(key)
    root_path(sort: key, direction: @direction)
  end

  def sort_direction_path
    root_path(sort: @sort, direction: @direction == "asc" ? "desc" : "asc")
  end

  def sort_direction_label
    @direction == "asc" ? "Oldest first" : "Newest first"
  end

  # The board sorts by one timestamp at a time; showing the other one on the
  # card would just be a number that does not match the order the eye sees.
  def card_timestamp(note)
    stamp = @sort == "created" ? note.created_at : note.updated_at
    tag.time(time_ago_in_words(stamp), datetime: stamp.iso8601,
      title: l(stamp, format: :long), class: "card__time")
  end
end
