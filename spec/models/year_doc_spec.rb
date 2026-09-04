require "rails_helper"

RSpec.describe YearDoc, type: :model do
  it "is one document per user per year" do
    duplicate = owner.year_docs.build(year: Date.current.year)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors.attribute_names).to include(:year)
  end

  it "allows the same year for another user" do
    doc = users(:other).year_docs.build(year: Date.current.year + 1)
    owner.year_docs.create!(year: Date.current.year + 1)

    expect(doc).to be_valid
  end

  it "stores plain text" do
    doc = owner.year_docs.create!(year: 2030, body: "1 jan\nwrite it down\n")

    expect(doc.body).to eq("1 jan\nwrite it down\n")
  end

  it "uses a UUID primary key" do
    expect(owner.year_docs.create!(year: 2031).id).to match(/\A[0-9a-f-]{36}\z/)
  end
end
