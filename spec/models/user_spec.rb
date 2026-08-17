require "rails_helper"

RSpec.describe User, type: :model do
  it "email is downcased and stripped on write" do
    user = User.create!(email: "  MiXeD@Noted.TEST  ", password: "a-long-password")

    expect(user.email).to eq("mixed@noted.test")
  end

  it "email is unique regardless of case" do
    duplicate = User.new(email: "OWNER@noted.test", password: "a-long-password")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors.attribute_names).to include(:email)
  end

  it "email must look like an address" do
    expect(User.new(email: "not-an-address", password: "a-long-password")).not_to be_valid
  end

  it "password has a minimum length but is not demanded on every update" do
    expect(User.new(email: "short@noted.test", password: "abc")).not_to be_valid

    owner.name = "Renamed"
    expect(owner).to be_valid, "updating a name must not require resupplying the password"
    expect(owner.save).to be_truthy
  end

  it "password is stored as a bcrypt digest and never recoverably" do
    user = User.create!(email: "hash@noted.test", password: "a-long-password")

    expect(user.password_digest).not_to eq("a-long-password")
    expect(user.authenticate("a-long-password")).to be_truthy
    expect(user.authenticate("wrong")).to be_falsey
  end

  it "verified_at exists but is unused" do
    expect(owner.verified_at).to be_nil
    expect(owner).not_to be_verified
  end

  it "storage is reported, not enforced" do
    expect(owner.storage_bytes).to eq(0)
    expect(User.new).not_to respond_to(:storage_quota)
  end
end
