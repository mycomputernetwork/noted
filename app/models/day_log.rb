class DayLog < ApplicationRecord
  include UuidPrimaryKey

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
