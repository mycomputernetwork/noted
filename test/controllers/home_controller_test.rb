require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "the smoke-test page renders the whole stack" do
    get root_path

    assert_response :success
    assert_select "h1", "notbuk"
  end

  test "the current_user stub resolves to the first user until milestone 7" do
    get root_path

    assert_match users(:owner).email, response.body
  end

  test "no other account's content reaches the page" do
    get root_path

    assert_no_match notes(:other_note).title, response.body
    assert_no_match day_entries(:other_event).body, response.body
  end

  test "the health check answers without a session" do
    get rails_health_check_path

    assert_response :success
  end
end
