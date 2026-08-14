Rails.application.routes.draw do
  # The tiled board is the front door (PRD §6). The rest of the IA arrives
  # with its milestone:
  #
  #   get  "/calendar"        -> milestone 6
  #   get  "/archive", "/trash", "/search" -> milestone 8
  #
  root "notes#index"

  # A folder is a board filtered to it (§7.3) plus the three things the
  # sidebar can do to it. Filing a note into a folder is not here: it is an
  # update to the note, and goes through the note's own endpoint.
  resources :folders, only: %i[show edit create update destroy]

  # The editor (PRD §8.2). `new` renders the composer and `show` renders
  # either the modal or the full pane depending on how it was asked for
  # (§7.7); the other three are the autosave controller's endpoints and
  # answer JSON, not HTML — they are called by a fetch, never by a form
  # submission, because saving is implicit and there is no submit button
  # anywhere in the interface (PRD §8.1).
  resources :notes, only: %i[new show create update destroy]

  get "up" => "rails/health#show", as: :rails_health_check
end
