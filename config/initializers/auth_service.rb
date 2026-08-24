require "auth_service"

raise "AUTH_MODE=stub refuses to boot outside development and test" if AuthService.stubbed? && !Rails.env.local?

unless AuthService.stubbed?
  # The openid_connect gem builds discovery URLs as https unconditionally, which
  # is right everywhere except a local auth on http://localhost:3001.
  if AuthService.issuer.start_with?("http://")
    SWD.url_builder = URI::HTTP
  end

  Rails.application.config.middleware.use OmniAuth::Builder do
    provider :openid_connect,
             name: :oidc,
             issuer: AuthService.issuer,
             discovery: true,
             scope: %i[openid email profile offline_access],
             response_type: :code,
             pkce: true,
             # No idp hint: auth offers Google and a password, and choosing
             # between them is its page's job, not noted's.
             client_options: {
               identifier: AuthService.client_id,
               secret: AuthService.client_secret,
               redirect_uri: "#{ENV.fetch("NOTED_URL", "http://localhost:3000")}/auth/oidc/callback"
             }
  end

  OmniAuth.config.allowed_request_methods = [:post]
  OmniAuth.config.on_failure = proc { |env| SessionsController.action(:failure).call(env) }
end
