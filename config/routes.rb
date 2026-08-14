Rails.application.routes.draw do
  # Milestone 1 ships a data layer and a smoke-test page. The real IA
  # (PRD §6) arrives with milestone 2:
  #
  #   root           "notes#index"    -> tiled board, undated notes
  #   get  "/diary"  "diary#show"     -> vertical day stream
  #   resources :folders
  #   get  "/archive", "/trash", "/search"
  #
  root "home#index"

  get "up" => "rails/health#show", as: :rails_health_check
end
