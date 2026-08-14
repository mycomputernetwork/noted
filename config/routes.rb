Rails.application.routes.draw do
  # The tiled board is the front door (PRD §6). The rest of the IA arrives
  # with its milestone:
  #
  #   get  "/calendar"        -> milestone 6
  #   resources :folders      -> milestone 4
  #   get  "/archive", "/trash", "/search" -> milestone 8
  #
  root "notes#index"

  # The editor (PRD §8.2). `new` and `show` render the dialog into the board's
  # turbo frame; the other three are the autosave controller's endpoints and
  # answer JSON, not HTML — they are called by a fetch, never by a form
  # submission, because saving is implicit and there is no submit button
  # anywhere in the interface (PRD §8.1).
  resources :notes, only: %i[new show create update destroy]

  get "up" => "rails/health#show", as: :rails_health_check
end
