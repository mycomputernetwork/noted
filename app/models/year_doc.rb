class YearDoc < ApplicationRecord
  include UuidPrimaryKey

  belongs_to :user

  before_validation { self.body = body.to_s }

  validates :year,
    presence: true,
    numericality: { only_integer: true, in: 1900..2200 },
    uniqueness: { scope: :user_id }
end
