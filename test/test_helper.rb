ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    fixtures :all

    # Two accounts exist in every test so isolation is testable by default.
    def owner = users(:owner)
    def other = users(:other)
  end
end
