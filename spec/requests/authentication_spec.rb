require "rails_helper"

RSpec.describe "Federated sign-in", type: :request do
  it "sends a signed-out visitor to sign in" do
    get root_path

    expect(response).to redirect_to(sign_in_path)
    follow_redirect!
    expect(response).to have_http_status(:ok)
  end

  it "offers the Android APK on the sign-in page" do
    get sign_in_path

    expect(response.body).to include(AndroidRelease::LATEST_DOWNLOAD_URL)
  end

  it "creates a session and a user the first time an identity arrives" do
    expect { post "/dev/sign_in", params: { email: "dev1@example.com" } }
      .to change(User, :count).by(1).and change(Session, :count).by(1)

    signed_in = User.find_by!(auth_sub: "stub-1")
    expect(signed_in).to have_attributes(email: "dev1@example.com", name: "Dev user 1")
    expect(signed_in.sessions.sole.sid).to be_present
    follow_redirect!
    expect(response).to have_http_status(:ok)
  end

  it "keeps the same account when a user signs in twice" do
    post "/dev/sign_in", params: { email: "dev1@example.com" }

    expect { post "/dev/sign_in", params: { email: "dev1@example.com" } }.not_to change(User, :count)
  end

  it "matches an existing account by its auth subject, not its email" do
    sign_in_as(owner)

    expect(owner.sessions.order(:created_at).last.ip_address).to be_present
  end

  it "ends the session on sign out" do
    sign_in_as

    expect { delete logout_path }.to change(Session, :count).by(-1)
    get root_path
    expect(response).to redirect_to(sign_in_path)
  end
end

RSpec.describe "Signing out of auth as well", type: :request do
  let(:endpoint) { "http://localhost:3001/oauth/logout" }

  before { allow(AuthService).to receive(:end_session_endpoint).and_return(endpoint) }

  it "hands the browser on to auth carrying the ID token it signed in with" do
    sign_in_as
    id_token = current_session_of(owner).id_token

    delete logout_path

    query = Rack::Utils.parse_query(URI(response.location).query)
    expect(URI(response.location).to_s).to start_with(endpoint)
    expect(query).to include(
      "id_token_hint" => id_token,
      "client_id" => AuthService.client_id,
      "post_logout_redirect_uri" => sign_in_url
    )
  end

  it "ends noted's own session before it leaves" do
    sign_in_as

    expect { delete logout_path }.to change(Session, :count).by(-1)

    get root_path
    expect(response).to redirect_to(sign_in_path)
  end

  it "signs out locally when auth publishes no end-session endpoint" do
    allow(AuthService).to receive(:end_session_endpoint).and_return(nil)
    sign_in_as

    delete logout_path

    expect(response).to redirect_to(sign_in_path)
  end
end

RSpec.describe "Bearer authentication on the API", type: :request do
  it "accepts a token issued for this app" do
    get "/api/v1/folders", headers: bearer_headers(owner)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.map { |folder| folder["id"] }).to include(folders(:owner_books).id)
  end

  it "scopes to the token's subject, not to whoever asked" do
    get "/api/v1/folders", headers: bearer_headers(other)

    expect(response.parsed_body.map { |folder| folder["id"] }).not_to include(folders(:owner_books).id)
  end

  it "refuses a request with no token" do
    get "/api/v1/folders"

    expect(response).to have_http_status(:unauthorized)
    expect(response.headers["WWW-Authenticate"]).to include("Bearer")
  end

  it "refuses an expired token" do
    get "/api/v1/folders", headers: bearer_headers(owner, exp: 1.minute.ago.to_i)

    expect(response).to have_http_status(:unauthorized)
  end

  it "refuses a token minted for another audience" do
    get "/api/v1/folders", headers: bearer_headers(owner, aud: "chat")

    expect(response).to have_http_status(:unauthorized)
  end

  it "accepts a token minted for the native client, which is noted too" do
    allow(AuthService).to receive(:native_client_id).and_return("noted-android")

    get "/api/v1/folders", headers: bearer_headers(owner, aud: "noted-android")

    expect(response).to have_http_status(:ok)
  end

  it "refuses a token from another issuer" do
    get "/api/v1/folders", headers: bearer_headers(owner, iss: "https://evil.example")

    expect(response).to have_http_status(:unauthorized)
  end

  it "refuses a token signed with the wrong key" do
    forged = JWT.encode({ iss: StubIssuer::ISSUER, aud: StubIssuer::CLIENT_ID, sub: owner.auth_sub,
                          exp: 1.hour.from_now.to_i }, OpenSSL::PKey::RSA.generate(2048), "RS256")

    get "/api/v1/folders", headers: { "Authorization" => "Bearer #{forged}" }

    expect(response).to have_http_status(:unauthorized)
  end

  it "refuses a token whose subject has no account here" do
    get "/api/v1/folders", headers: { "Authorization" => "Bearer #{StubIssuer.access_token({ sub: "nobody", email: "nobody@example.com" })}" }

    expect(response).to have_http_status(:unauthorized)
  end

  it "admits that subject once its ID token has been through the session endpoint" do
    identity = { sub: "nobody", email: "nobody@example.com", name: "Nobody" }

    post "/api/v1/session", headers: { "Authorization" => "Bearer #{StubIssuer.id_token(identity)}" }
    get "/api/v1/folders", headers: { "Authorization" => "Bearer #{StubIssuer.access_token(identity)}" }

    expect(response).to have_http_status(:ok)
  end

  it "serves the web app's own JavaScript on a cookie instead" do
    sign_in_as

    post api_v1_notes_path, params: { note: { title: "From the editor", body: "" } }

    expect(response).to have_http_status(:success)
    expect(owner.notes.reload.map(&:title)).to include("From the editor")
  end
end

RSpec.describe "Back-channel logout", type: :request do
  it "deletes the session auth names, and no other" do
    sign_in_as
    session = current_session_of(owner)
    elsewhere = other.sessions.create!(sid: "another-sid")

    post "/auth/backchannel_logout",
         params: { logout_token: StubIssuer.logout_token(sid: session.sid, subject: owner.auth_sub) }

    expect(response).to have_http_status(:ok)
    expect(Session.exists?(session.id)).to be(false)
    expect(Session.exists?(elsewhere.id)).to be(true)
  end

  it "leaves the account itself alone" do
    sign_in_as
    session = current_session_of(owner)

    post "/auth/backchannel_logout",
         params: { logout_token: StubIssuer.logout_token(sid: session.sid, subject: owner.auth_sub) }

    expect(owner.reload).to be_present
  end

  it "refuses an access token wearing a logout token's clothes" do
    sign_in_as
    session = current_session_of(owner)

    post "/auth/backchannel_logout", params: { logout_token: access_token_for(owner) }

    expect(response).to have_http_status(:bad_request)
    expect(Session.exists?(session.id)).to be(true)
  end

  it "refuses a logout token carrying a nonce" do
    sign_in_as
    session = current_session_of(owner)
    token = StubIssuer.encode({
      iss: StubIssuer::ISSUER, aud: StubIssuer::CLIENT_ID, sub: owner.auth_sub, sid: session.sid,
      exp: 2.minutes.from_now.to_i, nonce: "n", events: { LogoutToken::EVENT => {} }
    })

    post "/auth/backchannel_logout", params: { logout_token: token }

    expect(response).to have_http_status(:bad_request)
  end

  it "refuses a logout token signed by someone else" do
    sign_in_as

    forged = JWT.encode({ iss: StubIssuer::ISSUER, aud: StubIssuer::CLIENT_ID, sub: owner.auth_sub,
                          sid: current_session_of(owner).sid, exp: 2.minutes.from_now.to_i,
                          events: { LogoutToken::EVENT => {} } },
                        OpenSSL::PKey::RSA.generate(2048), "RS256")

    post "/auth/backchannel_logout", params: { logout_token: forged }

    expect(response).to have_http_status(:bad_request)
  end
end

RSpec.describe "The development stub", type: :request do
  it "refuses an identity auth would not have allowlisted" do
    expect { post "/dev/sign_in", params: { email: "dev3@example.com" } }
      .not_to change(Session, :count)

    expect(response).to redirect_to(sign_in_path)
  end

  it "refuses an identity auth has revoked" do
    expect { post "/dev/sign_in", params: { email: "dev4@example.com" } }
      .not_to change(Session, :count)
  end

  it "hands a native client a token only for an identity in good standing" do
    post "/dev/token", params: { email: "dev1@example.com" }
    expect(response.parsed_body["access_token"]).to be_present

    post "/dev/token", params: { email: "dev4@example.com" }
    expect(response).to have_http_status(:forbidden)
  end
end

RSpec.describe "Switching issuers", type: :request do
  it "does not carry a stub session into a run against the real provider" do
    sign_in_as
    get root_path
    expect(response).to have_http_status(:ok)

    allow(AuthService).to receive(:issuer).and_return("http://localhost:3001")

    get root_path
    expect(response).to redirect_to(sign_in_path)
  end
end

RSpec.describe "The account menu", type: :request do
  it "offers a way out on every page" do
    sign_in_as
    get root_path

    expect(response.body).to include(owner.email)
    assert_select "form[action=?][method=?]", logout_path, "post"
  end
end
