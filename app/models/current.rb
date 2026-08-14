# Request-scoped identity. Set by the Authentication concern on every request
# and reset by Rails between requests.
class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :user
end
