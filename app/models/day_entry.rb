class DayEntry < ApplicationRecord
  KINDS = %w[event action].freeze

  belongs_to :user

  enum :kind, { event: "event", action: "action" }, validate: true

  validates :date, presence: true
  validates :start_minute,
    numericality: { only_integer: true, in: 0..1439 },
    allow_nil: true

  validate :time_is_events_only
  validate :completion_is_actions_only

  before_validation :assign_position, on: :create

  # --- Lifecycle -----------------------------------------------------------
  scope :kept,    -> { where(deleted_at: nil) }
  scope :trashed, -> { where.not(deleted_at: nil) }

  # --- Reading a day -------------------------------------------------------
  scope :on,     ->(date)  { where(date: date) }
  scope :during, ->(range) { where(date: range) }

  def self.in_year(year)
    during(Date.new(year, 1, 1)..Date.new(year, 12, 31))
  end

  # Timed events first in clock order, then everything untimed in manual
  # order. SQLite sorts NULLs first by default, so the CASE forces them last.
  scope :in_day_order, -> {
    order(Arel.sql("CASE WHEN start_minute IS NULL THEN 1 ELSE 0 END"))
      .order(:start_minute, :position, :id)
  }

  # --- Actions -------------------------------------------------------------
  scope :open_actions,      -> { action.kept.where(completed_at: nil) }
  scope :completed_actions, -> { action.kept.where.not(completed_at: nil) }

  # Unfinished actions from *before* a given day, surfaced on that day so they
  # are not silently stranded in the past.
  #
  # The rollover is a read, not a write: `date` keeps recording when the thing
  # was originally planned for, and no nightly job re-dates anything. The cost
  # is one extra query per day render, which the partial index covers.
  scope :carried_into, ->(date) { open_actions.where(date: ...date).order(:date, :position, :id) }

  def open?      = action? && completed_at.nil?
  def completed? = completed_at.present?

  def complete!   = update!(completed_at: Time.current)
  def uncomplete! = update!(completed_at: nil)
  def toggle!     = completed? ? uncomplete! : complete!

  def overdue?(today = Date.current) = open? && date < today

  # --- Time ----------------------------------------------------------------
  def timed? = start_minute.present?

  # "14:30", or nil.
  def start_time
    return nil if start_minute.nil?

    format("%02d:%02d", start_minute / 60, start_minute % 60)
  end

  # Accepts "14:30", "1430", "2:30 pm" or an Integer. Blank clears the time.
  def start_time=(value)
    self.start_minute =
      case value
      when nil, "" then nil
      when Integer then value
      else self.class.parse_minute(value)
      end
  end

  def self.parse_minute(value)
    text = value.to_s.strip.downcase
    return nil if text.empty?

    # Trailing am/pm in any of the forms a person types: "pm", "p", "p.m."
    meridiem = text[/([ap])\.?m?\.?\s*\z/, 1]
    digits = text.gsub(/[^0-9]/, "")
    return nil if digits.empty?

    hour, minute =
      if digits.length <= 2 then [ digits.to_i, 0 ]
      else [ digits[0..-3].to_i, digits[-2..].to_i ]
      end

    hour = 0 if meridiem == "a" && hour == 12
    hour += 12 if meridiem == "p" && hour < 12
    return nil unless hour.between?(0, 23) && minute.between?(0, 59)

    hour * 60 + minute
  end

  def empty? = body.blank?

  def trash!   = update!(deleted_at: Time.current)
  def restore! = update!(deleted_at: nil)

  private
    def assign_position
      return if position.to_i.positive? || user.nil? || date.nil?

      self.position = (user.day_entries.on(date).maximum(:position) || -1) + 1
    end

    def time_is_events_only
      return if start_minute.nil? || event?

      errors.add(:start_minute, :events_only)
    end

    def completion_is_actions_only
      return if completed_at.nil? || action?

      errors.add(:completed_at, :actions_only)
    end
end
