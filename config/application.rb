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

    config.generators do |g|
      g.orm :active_record, primary_key_type: :string
      g.test_framework :test_unit
      g.helper false
      g.assets false
      g.system_tests nil
    end

    # No autosave debounce here. The window (PRD §8.1) is declared once, as
    # autosave_controller.js's `delay` value, where the timer that uses it
    # lives. A copy on this side would have been read by nothing — and a
    # constant that documents a coupling which does not exist is worse than
    # no constant, because the next person wires the two together on the
    # strength of the comment.
  end
end
