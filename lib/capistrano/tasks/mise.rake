namespace :mise do
  desc "Install mise if not present"
  task :install do
    on roles(:app) do
      unless test("[ -f ~/.local/bin/mise ]")
        execute "curl https://mise.run | sh"
      end
    end
  end

  desc "Install Ruby via mise"
  task :setup_ruby do
    on roles(:app) do
      within release_path do
        execute "~/.local/bin/mise install"
      end
    end
  end

  desc "Verify mise and Ruby"
  task :verify do
    on roles(:app) do
      within release_path do
        info "mise version: #{capture("~/.local/bin/mise --version")}"
        info "Ruby version: #{capture("~/.local/bin/mise exec -- ruby --version")}"
      end
    end
  end

  desc "Trust .mise.toml in release directory"
  task :trust_config do
    on roles(:app) do
      within release_path do
        execute "~/.local/bin/mise", "trust"
      end
    end
  end
end

before "deploy:updated", "mise:install"
before "deploy:updated", "mise:setup_ruby"
after "deploy:symlink:linked_dirs", "mise:trust_config"
