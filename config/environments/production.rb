require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true

  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # TLS is terminated by `tailscale serve` in front of the app (PRD §14).
  # force_ssl would redirect the plain-HTTP hop from the proxy back to itself,
  # so it stays off; assume_ssl tells Rails the original request was secure so
  # session cookies are still marked secure.
  config.assume_ssl = true
  config.force_ssl = false

  config.log_tags = [ :request_id ]
  config.logger = ActiveSupport::TaggedLogging.logger(STDOUT)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  config.silence_healthcheck_path = "/up"

  config.active_support.report_deprecations = false

  config.cache_store = :solid_cache_store

  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  config.active_storage.service = :production_disk

  config.action_mailer.perform_caching = false
  # Still no delivery in production (PRD §12.3, open question 1). :test drops
  # messages on the floor rather than raising; password reset logs its URL.
  config.action_mailer.delivery_method = :test
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.default_url_options = {
    host: ENV.fetch("NOTED_HOST", "localhost"), protocol: "https"
  }

  config.i18n.fallbacks = true

  config.active_record.dump_schema_after_migration = false
  config.active_record.attributes_for_inspect = [ :id ]

  # Only the tailnet hostname may address the app.
  config.hosts << ENV["NOTED_HOST"] if ENV["NOTED_HOST"].present?
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
