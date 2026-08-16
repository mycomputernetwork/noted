Rails.application.routes.draw do
  root "notes#index"

  resources :folders, only: %i[show edit create update destroy]

  # Filing is a PATCH to the note (folder_id), so it needs no route of its own.
  resources :notes, only: %i[new show create update destroy]

  get "up" => "rails/health#show", as: :rails_health_check
end
