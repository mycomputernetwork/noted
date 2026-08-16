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

  def actionable = carried + open_actions

  def log_body = log&.body.to_s

  def today?   = date == @today
  def past?    = date < @today
  def future?  = date > @today
  def weekend? = date.saturday? || date.sunday?

  def empty? = entries.empty? && carried.empty? && log_body.blank?

  def month_start? = date.day == 1

  def to_param = date.iso8601
end
