namespace :noted do
  desc "Upload the production credentials key if the server doesn't have it"
  task :setup_credentials_key do
    on roles(:app) do
      key = "config/credentials/production.key"

      unless test("[ -f #{shared_path}/#{key} ]")
        if File.exist?(key)
          execute :mkdir, "-p", "#{shared_path}/config/credentials"
          upload! key, "#{shared_path}/#{key}"
        else
          error "#{key} is missing locally; production cannot decrypt its credentials without it."
          exit 1
        end
      end
    end
  end

  desc "Prepare databases"
  task :db_prepare do
    on roles(:db) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute "~/.local/bin/mise", "exec", "--", "bundle", "exec", "rails", "db:prepare"
        end
      end
    end
  end

  desc "Precompile assets"
  task :assets_precompile do
    on roles(:app) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute "~/.local/bin/mise", "exec", "--", "bundle", "exec", "rails", "assets:precompile"
        end
      end
    end
  end

  desc "Create launchd plist"
  task :setup_launchd do
    on roles(:app) do
      home = capture("echo $HOME").strip
      launchagents = "#{home}/Library/LaunchAgents"
      execute :mkdir, "-p", launchagents
      plist_path = "#{launchagents}/com.noted.app.plist"
      mise_bin = "#{home}/.local/bin/mise"

      plist_content = <<~PLIST
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>Label</key>
          <string>com.noted.app</string>
          
          <key>ProgramArguments</key>
          <array>
            <string>#{mise_bin}</string>
            <string>exec</string>
            <string>--</string>
            <string>bundle</string>
            <string>exec</string>
            <string>puma</string>
            <string>-C</string>
            <string>config/puma.rb</string>
          </array>
          
          <key>WorkingDirectory</key>
          <string>#{current_path}</string>
          
          <key>EnvironmentVariables</key>
          <dict>
            <key>RAILS_ENV</key>
            <string>production</string>
            <key>NOTED_DB_PATH</key>
            <string>#{shared_path}/db_data</string>
            <key>RAILS_LOG_TO_STDOUT</key>
            <string>true</string>
            <key>RAILS_SERVE_STATIC_FILES</key>
            <string>true</string>
            <key>PORT</key>
            <string>3000</string>
            <key>NOTED_URL</key>
            <string>#{fetch(:noted_url)}</string>
            <key>NOTED_HOST</key>
            <string>#{URI(fetch(:noted_url)).host}</string>
          </dict>
          
          <key>RunAtLoad</key>
          <true/>
          
          <key>KeepAlive</key>
          <true/>
          
          <key>StandardOutPath</key>
          <string>#{shared_path}/log/launchd.out.log</string>
          
          <key>StandardErrorPath</key>
          <string>#{shared_path}/log/launchd.err.log</string>
        </dict>
        </plist>
      PLIST
      
      upload! StringIO.new(plist_content), plist_path
      execute "launchctl", "unload", plist_path rescue nil
      execute "launchctl", "load", plist_path
      info "launchd service configured and loaded at #{plist_path}"
    end
  end

  desc "Restart the application"
  task :restart do
    on roles(:app) do
      execute "launchctl", "kickstart", "-k", "gui/#{capture(:id, '-u')}/com.noted.app"
      info "Application restarted"
    end
  end

  desc "Stop the application"
  task :stop do
    on roles(:app) do
      execute "launchctl", "stop", "com.noted.app" rescue nil
    end
  end

  desc "Check application status"
  task :status do
    on roles(:app) do
      status = capture("launchctl list | grep com.noted.app || echo 'Not running'")
      info "Status: #{status}"
    end
  end
end

before "deploy:check:linked_files", "noted:setup_credentials_key"
after "deploy:migrate", "noted:db_prepare"
after "noted:db_prepare", "noted:assets_precompile"
after "deploy:publishing", "noted:setup_launchd"
after "deploy:publishing", "noted:restart"
