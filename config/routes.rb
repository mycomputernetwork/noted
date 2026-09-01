require "auth_service"

Rails.application.routes.draw do
  if defined?(Rswag::Ui::Engine)
    mount Rswag::Ui::Engine => '/api-docs'
    mount Rswag::Api::Engine => '/api-docs'
  end
  root "notes#index"

  namespace :api do
    namespace :v1 do
      resources :notes, only: %i[index show create update destroy] do
        patch :reorder, on: :collection
      end
      resources :folders, only: %i[index show create update destroy]
      resources :changes, only: :index
      resource :session, only: :create
    end
  end

  get "sign_in", to: "sessions#new", as: :sign_in
  match "auth/oidc/callback", to: "sessions#create", via: %i[get post], as: :oidc_callback
  get "auth/failure", to: "sessions#failure"
  post "auth/backchannel_logout", to: "auth/backchannel_logouts#create"
  delete "logout", to: "sessions#destroy", as: :logout

  if AuthService.stubbed?
    post "dev/sign_in", to: "dev/sessions#create", as: :dev_sign_in
    post "dev/token", to: "dev/tokens#create"
  end

  resources :folders, only: %i[show edit create update destroy]

  # Filing is a PATCH to the note (folder_id), so it needs no route of its own.
  resources :notes, only: %i[new show]

  get "up" => "rails/health#show", as: :rails_health_check
end
