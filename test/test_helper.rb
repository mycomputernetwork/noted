ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    fixtures :all

    # dom_id in a test asserts against the same id the view generated, rather
    # than against a string that has to be kept in step with it by hand.
    include ActionView::RecordIdentifier

    # Two accounts exist in every test so isolation is testable by default.
    def owner = users(:owner)
    def other = users(:other)
  end
end

class ActionDispatch::IntegrationTest
  # From milestone 4 the sidebar renders every live note's title on every page
  # in the tree's ordering rather than the board's. So
  # `response.body.index(title)` stopped being a way to ask what order the
  # *board* is in — it finds the sidebar row first. Ask the board directly.
  def board_titles
    css_select(".board .card__title").map { |title| title.text.strip }
  end
end
