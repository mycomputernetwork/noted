# config valid for current version and patch releases of Capistrano
lock "~> 3.20.1"

set :application, "noted"
set :repo_url, "https://github.com/mycomputernetwork/noted.git"

set :branch, "main"

# Default value for :format is :airbrussh.
# set :format, :airbrussh

# You can configure the Airbrussh format using :format_options.
# These are the defaults.
# set :format_options, command_output: true, log_file: "log/capistrano.log", color: :auto, truncate: :auto

# Default value for :pty is false
# set :pty, true

append :linked_files, "config/credentials/production.key"

append :linked_dirs, "log", "tmp/pids", "tmp/cache", "tmp/sockets", "storage", "db_data"

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for local_user is ENV['USER']
# set :local_user, -> { `git config user.name`.chomp }

set :keep_releases, 2

# mise wraps the Ruby runtime
set :mise_ruby_version, "3.4.10"

# The OIDC redirect_uri is built from this and has to match the one registered
# on auth's client exactly.
set :noted_url, "https://noted.prabhanshugupta.com"

# Environment variables for production
set :default_env, {
  "PATH" => "$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH",
  "RAILS_ENV" => "production",
  "NOTED_DB_PATH" => "/Users/prabhanshu/services/noted/shared/db_data",
  "RAILS_LOG_TO_STDOUT" => "true",
  "RAILS_SERVE_STATIC_FILES" => "true",
  "NOTED_URL" => "https://noted.prabhanshugupta.com",
  "NOTED_HOST" => "noted.prabhanshugupta.com",
  # mise's Ruby is linked against a Homebrew OpenSSL whose cert.pem is not on
  # this machine, leaving it with no CA store: discovery and the JWKS fetch
  # against auth fail to verify. Point it at the system store.
  "SSL_CERT_FILE" => "/etc/ssl/cert.pem"
}

set :bundle_path, -> { shared_path.join('vendor/bundle') }
set :bundle_flags, '--deployment --quiet'
set :bundle_without, %w{development test}.join(' ')

# All commands run through mise to use the correct Ruby
SSHKit.config.command_map[:bundle] = "~/.local/bin/mise exec -- bundle"
SSHKit.config.command_map[:rake] = "~/.local/bin/mise exec -- bundle exec rake"
SSHKit.config.command_map[:rails] = "~/.local/bin/mise exec -- bundle exec rails"

# Uncomment the following to require manually verifying the host key before first deploy.
# set :ssh_options, verify_host_key: :secure
