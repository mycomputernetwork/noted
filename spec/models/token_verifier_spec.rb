require "rails_helper"

RSpec.describe TokenVerifier do
  let(:identity) { StubIssuer.identity_for(owner) }

  it "accepts a token minted for noted's own client" do
    claims = described_class.new.verify(StubIssuer.access_token(identity))

    expect(claims.subject).to eq(owner.auth_sub)
  end

  # A phone cannot hold noted's client secret, so its tokens are stamped with
  # the native client's uid. Both name noted.
  context "with a native client registered" do
    before do
      allow(AuthService).to receive(:client_id).and_return("noted")
      allow(AuthService).to receive(:native_client_id).and_return("noted-android")
    end

    it "accepts a token minted for the native client" do
      claims = described_class.new.verify(StubIssuer.access_token(identity, aud: "noted-android"))

      expect(claims.subject).to eq(owner.auth_sub)
    end

    it "accepts a token minted for the web client" do
      expect { described_class.new.verify(StubIssuer.access_token(identity, aud: "noted")) }.not_to raise_error
    end

    it "refuses a token minted for another app in the fleet" do
      expect { described_class.new.verify(StubIssuer.access_token(identity, aud: "chat")) }
        .to raise_error(AuthService::Error, /audience/i)
    end
  end
end
