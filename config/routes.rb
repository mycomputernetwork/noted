Rails.application.routes.draw do
  if defined?(Rswag::Ui::Engine)
    mount Rswag::Ui::Engine => '/api-docs'
    mount Rswag::Api::Engine => '/api-docs'
  end
  root "notes#index"

  namespace :api do
    namespace :v1 do
      resources :notes, only: %i[index show create update destroy]
      resources :folders, only: %i[index show create update destroy]
      resources :changes, only: :index
    end
  end

  resources :folders, only: %i[show edit create update destroy]

  # Filing is a PATCH to the note (folder_id), so it needs no route of its own.
  resources :notes, only: %i[new show]

  get "up" => "rails/health#show", as: :rails_health_check
end
