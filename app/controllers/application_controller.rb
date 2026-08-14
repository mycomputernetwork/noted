class ApplicationController < ActionController::Base
  include Authentication

  # Only modern browsers. Keeps the CSS free of fallbacks for things the
  # tiled board and sticky month headers rely on.
  allow_browser versions: :modern

  private
    # Every query in this application originates here. Nothing is ever loaded
    # by bare id from a global scope, in any controller, at any point — that
    # rule is the entire isolation model between accounts, so it has to be
    # habit rather than a later audit.
    def notes   = current_user.notes
    def folders = current_user.folders
    def entries = current_user.day_entries
    def logs    = current_user.day_logs
end
