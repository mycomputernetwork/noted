Rack::Attack.enabled = !Rails.env.test?

# Puma runs single-process here, so per-process counters are the whole picture
# and cost no database writes on the request path.
Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

Rack::Attack.safelist("health") { |req| req.get? && req.path == "/up" }

# Back-channel logout arrives from auth, one address for the whole fleet, and
# dropping it would leave a signed-out session alive here.
Rack::Attack.safelist("backchannel logout") do |req|
  req.post? && req.path == "/auth/backchannel_logout"
end

# Native clients hold a token each, so throttle the holder rather than the
# address: a household behind one NAT is one IP but several clients.
Rack::Attack.throttle("api by token", limit: 300, period: 1.minute) do |req|
  if req.path.start_with?("/api/")
    req.get_header("HTTP_AUTHORIZATION").presence || req.ip
  end
end

Rack::Attack.throttle("sign-in by ip", limit: 20, period: 1.minute) do |req|
  req.ip if req.path == "/sign_in" || req.path.start_with?("/auth/")
end

Rack::Attack.throttle("requests by ip", limit: 300, period: 1.minute) do |req|
  req.ip unless req.path.start_with?("/assets/")
end

Rack::Attack.throttled_responder = lambda do |request|
  retry_after = (request.env["rack.attack.match_data"] || {})[:period].to_i
  [ 429, { "content-type" => "text/plain", "retry-after" => retry_after.to_s }, [ "Too many requests\n" ] ]
end

ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |_name, _start, _finish, _id, payload|
  request = payload[:request]
  Rails.logger.warn("[rack-attack] #{request.env['rack.attack.matched']} #{request.ip} #{request.request_method} #{request.fullpath}")
end
