Rails.application.routes.draw do
  # The tiled board is the front door (PRD §6). The rest of the IA arrives
  # with its milestone:
  #
  #   get  "/calendar"        -> milestone 6
  #   resources :folders      -> milestone 4
  #   get  "/archive", "/trash", "/search" -> milestone 8
  #
  root "notes#index"

  get "up" => "rails/health#show", as: :rails_health_check
end
