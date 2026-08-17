module AccountHelpers
  def owner = users(:owner)
  def other = users(:other)
end

module BoardHelpers
  def board_titles
    css_select(".board .card__title").map { |title| title.text.strip }
  end
end

RSpec.configure do |config|
  config.include AccountHelpers
  config.include BoardHelpers, type: :request
  config.include ActionView::RecordIdentifier
end
