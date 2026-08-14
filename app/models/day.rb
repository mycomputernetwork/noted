# A single day in the calendar stream, composed for rendering. Not a table —
# days are not materialised, because a year is mostly empty and creating 365
# rows per user per year to hold nothing would be pure overhead.
#
# Composition, not inheritance from anything: it holds the day's entries, the
# day's log, and any open actions carried in from earlier days.
class Day
  attr_reader :date, :entries, :log, :carried

  def initialize(date:, entries: [], log: nil, carried: [], today: Date.current)
    @date = date
    @entries = entries
    @log = log
    @carried = carried
    @today = today
  end

  def events  = entries.select(&:event?)
  def actions = entries.select(&:action?)

  def open_actions      = actions.select(&:open?)
  def completed_actions = actions.select(&:completed?)

  # What the day's action list actually shows: today's open actions plus
  # anything unfinished dragged forward from before. Carried items keep their
  # original date so the UI can label them "from Tue".
  def actionable = carried + open_actions

  def log_body = log&.body.to_s

  def today?   = date == @today
  def past?    = date < @today
  def future?  = date > @today
  def weekend? = date.saturday? || date.sunday?

  # Drives the thin ~28px collapsed row in the stream.
  def empty? = entries.empty? && carried.empty? && log_body.blank?

  # Drives the sticky month header.
  def month_start? = date.day == 1

  def to_param = date.iso8601
end
