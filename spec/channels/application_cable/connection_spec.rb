require "rails_helper"

RSpec.describe ApplicationCable::Connection, type: :channel do
  it "connects with a browser session" do
    noted_session = other.sessions.create!(issuer: AuthService.issuer)

    connect session: { noted_session: noted_session.id }

    expect(connection.current_user).to eq(other)
  end

  it "connects with a bearer token" do
    token = StubIssuer.access_token(StubIssuer.identity_for(other))

    connect headers: { "Authorization" => "Bearer #{token}" }

    expect(connection.current_user).to eq(other)
  end

  it "rejects missing credentials" do
    expect { connect }.to have_rejected_connection
  end

  it "rejects a token that does not name a user" do
    token = StubIssuer.access_token({ sub: "missing", email: "missing@example.com" })

    expect { connect headers: { "Authorization" => "Bearer #{token}" } }.to have_rejected_connection
  end
end
