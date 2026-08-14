require "test_helper"

class SessionTest < ActiveSupport::TestCase
  test "last_active_at defaults to now so a new session is live" do
    session = owner.sessions.create!

    assert_not_nil session.last_active_at
    assert_includes Session.live, session
  end

  test "sessions expire 30 days after last activity, not after creation" do
    stale = owner.sessions.create!(last_active_at: 31.days.ago)

    assert stale.expired?
    assert_includes Session.expired, stale
    assert_not_includes Session.live, stale
  end

  test "activity is only written when it is stale enough to matter" do
    session = sessions(:owner_laptop)
    before = session.last_active_at

    session.touch_activity!
    assert_equal before.to_i, session.reload.last_active_at.to_i,
      "a fresh session must not write on every request — SQLite would lock"

    session.update_column(:last_active_at, 2.hours.ago)
    session.touch_activity!
    assert_operator session.reload.last_active_at, :>, 1.minute.ago
  end

  test "revoking one device leaves the others signed in" do
    laptop = sessions(:owner_laptop)
    phone = owner.sessions.create!(user_agent: "phone")

    laptop.destroy!

    assert_equal [ phone ], owner.sessions.reload.to_a
  end
end
