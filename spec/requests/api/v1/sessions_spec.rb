require "swagger_helper"

RSpec.describe "api/v1/session", type: :request do
  let(:Authorization) { "Bearer #{StubIssuer.id_token(StubIssuer.identity_for(owner))}" }

  path "/api/v1/session" do
    post "establishes the account behind a token" do
      tags "Session"
      security [ { idTokenAuth: [] } ]
      description <<~DESC
        Takes an **ID token** — not an access token — and returns the account it
        identifies, creating it on a first sign-in. Every other endpoint resolves
        an existing account by the token's subject and never creates one, and an
        access token carries no email to create from, so a native client calls
        this once after a sign-in completes and then uses its access token
        everywhere else.
      DESC
      produces "application/json"

      response "200", "first sign-in for an identity noted has never seen" do
        schema "$ref" => "#/components/schemas/User"
        let(:Authorization) { "Bearer #{StubIssuer.id_token(StubIssuer.identity('dev1@example.com'))}" }

        run_test! do
          expect(User.find_by!(auth_sub: "stub-1")).to have_attributes(email: "dev1@example.com", name: "Dev user 1")
        end
      end

      response "200", "the account, found by subject or created from the token's claims" do
        schema "$ref" => "#/components/schemas/User"

        run_test! do
          expect(response.parsed_body).to include("id" => owner.id, "email" => owner.email, "name" => owner.name)
        end
      end

      response "401", "an access token was sent instead of an ID token" do
        schema "$ref" => "#/components/schemas/Error"
        let(:Authorization) { bearer_headers(owner)["Authorization"] }

        run_test! do
          expect(response.headers["WWW-Authenticate"]).to include("invalid_token")
        end
      end

      response "401", "the token is missing, expired, or issued for another audience" do
        schema "$ref" => "#/components/schemas/Error"
        let(:Authorization) { nil }
        run_test!
      end
    end
  end
end
