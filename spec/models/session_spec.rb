require "rails_helper"

RSpec.describe Session, type: :model do
  it "last_active_at defaults to now so a new session is live" do
    session = owner.sessions.create!

    expect(session.last_active_at).not_to be_nil
    expect(Session.live).to include(session)
  end

  it "sessions expire 30 days after last activity, not after creation" do
    stale = owner.sessions.create!(last_active_at: 31.days.ago)

    expect(stale).to be_expired
    expect(Session.expired).to include(stale)
    expect(Session.live).not_to include(stale)
  end

  it "activity is only written when it is stale enough to matter" do
    session = sessions(:owner_laptop)
    before = session.last_active_at

    session.touch_activity!
    expect(session.reload.last_active_at.to_i).to eq(before.to_i),
      "a fresh session must not write on every request — SQLite would lock"

    session.update_column(:last_active_at, 2.hours.ago)
    session.touch_activity!
    expect(session.reload.last_active_at).to be > 1.minute.ago
  end

  it "revoking one device leaves the others signed in" do
    laptop = sessions(:owner_laptop)
    phone = owner.sessions.create!(user_agent: "phone")

    laptop.destroy!

    expect(owner.sessions.reload.to_a).to eq([ phone ])
  end
end
