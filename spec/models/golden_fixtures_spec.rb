require "rails_helper"

# The reference tokens auth's own suite froze, copied here by
# `rake auth:golden_fixtures[../noted]`. Verifying them through the real
# TokenVerifier proves the vendored copy still accepts what auth mints, and
# comparing claim sets proves the stub has not drifted from it. A claim added
# to auth without recopying turns this red.
RSpec.describe "Golden fixtures" do
  include ActiveSupport::Testing::TimeHelpers

  let(:golden) { JSON.parse(Rails.root.join("spec/fixtures/auth/golden.json").read) }

  let(:verifier) { TokenVerifier.new }

  before do
    allow(AuthService).to receive(:issuer).and_return(golden["issuer"])
    allow(AuthService).to receive(:client_id).and_return(golden["audience"])
    allow(StubIssuer).to receive(:jwks).and_return(golden["jwks"])
    travel_to(Time.at(golden["minted_at"]))
  end

  after { travel_back }

  it "verifies auth's access token through the vendored TokenVerifier" do
    claims = verifier.verify(golden["access_token"])

    expect(claims.subject).to eq(golden["subject"])
    expect(claims.sid).to eq(golden["sid"])
  end

  it "verifies auth's id token, the identity the sign-in paths read" do
    claims = verifier.verify(golden["id_token"])

    expect(claims).to have_attributes(
      subject: golden["subject"], email: golden["email"], name: golden["name"], sid: golden["sid"]
    )
  end

  it "accepts auth's logout token" do
    claims = LogoutToken.verify(golden["logout_token"])

    expect(claims.sid).to eq(golden["sid"])
  end

  it "mints an access token with the same claims auth does" do
    expect(stub_claims(:access_token)).to eq(auth_claims("access_token"))
  end

  it "mints an id token with the same claims auth does" do
    expect(stub_claims(:id_token)).to eq(auth_claims("id_token"))
  end

  it "mints a logout token with the same claims auth does" do
    stub = StubIssuer.logout_token(sid: golden["sid"], subject: golden["subject"])

    expect(keys(stub)).to eq(auth_claims("logout_token"))
  end

  def identity = { sub: golden["subject"], email: golden["email"], name: golden["name"] }

  def stub_claims(kind) = keys(StubIssuer.public_send(kind, identity))

  def auth_claims(kind) = keys(golden[kind])

  def keys(jwt) = JWT.decode(jwt, nil, false).first.keys.sort
end
