require_relative "boot"

require "rails"

# Load only the frameworks this app actually uses. Notably absent:
# action_mailbox (no inbound mail), action_text (body is plain text — PRD §3),
# action_cable is present only because Turbo Streams may want it later.
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "action_cable/engine"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

module Notbuk
  class Application < Rails::Application
    config.load_defaults 8.1

    # Autoload lib/, minus the directories that are not Zeitwerk-shaped.
    config.autoload_lib(ignore: %w[assets tasks])

    # The app is single-timezone by construction: one household, one server.
    # entry_date is a Date, so this only affects created_at/updated_at display.
    config.time_zone = "Asia/Kolkata"
    config.active_record.default_timezone = :utc

    # Generators: no scaffold CSS, no helper/view specs we won't write.
    config.generators do |g|
      g.test_framework :test_unit
      g.helper false
      g.assets false
      g.system_tests nil
    end

    # Trash is purged 30 days after deletion (PRD §7.5).
    config.x.trash_retention = 30.days

    # Debounce window the autosave controller uses (PRD §8.1). Lives here so
    # the value is shared between the JS controller and any server-side use.
    config.x.autosave_debounce_ms = 800
  end
end
