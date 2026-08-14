# "Things I did today" — one free-text block per day, per user.
#
# Distinct from DayEntry: entries are things planned *for* the day (events and
# actions), the log is the record of what actually happened. They are separate
# objects because they are written at different times of day and edited with
# different rhythms — the log is one growing paragraph, entries are discrete
# lines that get checked off.
class DayLog < ApplicationRecord
  belongs_to :user

  validates :date, presence: true
  validates :date, uniqueness: { scope: :user_id }

  scope :on,     ->(date)  { where(date: date) }
  scope :during, ->(range) { where(date: range) }
  scope :written, -> { where.not(body: "") }

  def self.in_year(year)
    during(Date.new(year, 1, 1)..Date.new(year, 12, 31))
  end

  def empty? = body.blank?
end
