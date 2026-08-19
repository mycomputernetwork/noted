module AccountHelpers
  def owner = users(:owner)
  def other = users(:other)
end

# AUTH_MODE=stub in test: tokens are real, signed with the checked-in keypair
# and verified through TokenVerifier, so specs exercise the same path as
# production (ADR 0003).
module AuthHelpers
  def sign_in_as(user = owner)
    post "/dev/sign_in", params: { email: user.email }
  end

  def bearer_headers(user = owner, **overrides)
    { "Authorization" => "Bearer #{access_token_for(user, **overrides)}" }
  end

  # Primary keys are UUIDs, so `Session.last` is not the newest row.
  def current_session_of(user) = user.sessions.order(:created_at).last

  def access_token_for(user, **overrides)
    StubIssuer.access_token(StubIssuer.identity_for(user), **overrides)
  end
end

module BoardHelpers
  def board_titles
    css_select(".board .card__title").map { |title| title.text.strip }
  end
end

RSpec.configure do |config|
  config.include AccountHelpers
  config.include AuthHelpers, type: :request
  config.include BoardHelpers, type: :request
  config.include ActionView::RecordIdentifier
end
