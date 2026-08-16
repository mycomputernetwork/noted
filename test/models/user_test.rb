require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "email is downcased and stripped on write" do
    user = User.create!(email: "  MiXeD@Noted.TEST  ", password: "a-long-password")

    assert_equal "mixed@noted.test", user.email
  end

  test "email is unique regardless of case" do
    duplicate = User.new(email: "OWNER@noted.test", password: "a-long-password")

    assert_not duplicate.valid?
    assert_includes duplicate.errors.attribute_names, :email
  end

  test "email must look like an address" do
    assert_not User.new(email: "not-an-address", password: "a-long-password").valid?
  end

  test "password has a minimum length but is not demanded on every update" do
    assert_not User.new(email: "short@noted.test", password: "abc").valid?

    owner.name = "Renamed"
    assert owner.valid?, "updating a name must not require resupplying the password"
    assert owner.save
  end

  test "password is stored as a bcrypt digest and never recoverably" do
    user = User.create!(email: "hash@noted.test", password: "a-long-password")

    assert_not_equal "a-long-password", user.password_digest
    assert user.authenticate("a-long-password")
    assert_not user.authenticate("wrong")
  end

  test "verified_at exists but is unused" do
    assert_nil owner.verified_at
    assert_not owner.verified?
  end

  test "storage is reported, not enforced" do
    assert_equal 0, owner.storage_bytes
    assert_not User.new.respond_to?(:storage_quota)
  end
end
