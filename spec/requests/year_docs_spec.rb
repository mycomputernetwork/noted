require "rails_helper"

RSpec.describe "year docs", type: :request do
  before { sign_in_as }

  it "renders the current year on the board" do
    get root_path

    assert_response :success
    assert_select ".calendar-panel textarea", text: /Standup/
  end

  it "does not render another user's calendar text" do
    get root_path

    expect(response.body).not_to include("Not yours")
  end

  it "saves a year document" do
    patch year_doc_path(2035), params: { year_doc: { body: "1 jan\nstart here\n" } }

    assert_response :success
    expect(owner.year_docs.find_by!(year: 2035).body).to eq("1 jan\nstart here\n")
  end

  it "does not create an empty year document" do
    expect {
      patch year_doc_path(2036), params: { year_doc: { body: "" } }
    }.not_to change { YearDoc.count }
  end

  it "treats missing body as blank" do
    expect { patch year_doc_path(2037) }.not_to change { YearDoc.count }
  end
end
