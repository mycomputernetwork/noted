source "https://rubygems.org"

ruby file: ".ruby-version"

# --- Framework -------------------------------------------------------------
gem "rails", "~> 8.1"

# Asset pipeline. No Node toolchain anywhere (PRD §13).
gem "propshaft"
gem "importmap-rails"

# Hotwire.
gem "turbo-rails"
gem "stimulus-rails"

# --- Data ------------------------------------------------------------------
# SQLite for everything. No Postgres, no Redis (PRD §13).
gem "sqlite3", ">= 2.1"
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# --- Server ----------------------------------------------------------------
gem "puma", ">= 6.0"

# --- Auth ------------------------------------------------------------------
# has_secure_password. Milestone 7 turns this on; the digest column ships now.
gem "bcrypt", "~> 3.1.7"

# --- Runtime ---------------------------------------------------------------
gem "bootsnap", require: false

# No `platforms:` anywhere in this file. This app runs on macOS and Linux only,
# both of which carry system tzdata, so tzinfo-data is not needed and the
# Windows/JRuby platform gating that Rails ships by default is dead weight.
# Dropping it also means the Gemfile parses under older Bundlers, which do not
# know the :windows platform name.

# Milestone 5 (images) will want this. Uncomment once libvips is on the server.
# gem "image_processing", "~> 1.2"

group :development, :test do
  gem "debug", require: "debug/prelude"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "web-console"

  # Milestone 9. Deploy is Capistrano over SSH, not Kamal (PRD §14).
  gem "capistrano", require: false
  gem "capistrano-rails", require: false
  gem "capistrano-bundler", require: false
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end
