class ApplicationController < ActionController::Base
  include Authentication

  # Only modern browsers. Keeps the CSS free of fallbacks for things the
  # tiled board and sticky month headers rely on.
  allow_browser versions: :modern

  # The sidebar is on every view (PRD §6), so it loads on every view — but
  # only on the requests that actually draw one. A turbo frame request renders
  # without the layout, and the autosave controller's endpoints answer JSON;
  # building the tree for either would be two queries thrown away on every
  # keystroke that lands.
  before_action :load_tree, if: :renders_sidebar?

  private
    def renders_sidebar?
      request.get? && request.format.html? && !turbo_frame_request?
    end

    def load_tree
      @tree = Tree.for(user: current_user)
    end

    # Every query in this application originates here. Nothing is ever loaded
    # by bare id from a global scope, in any controller, at any point — that
    # rule is the entire isolation model between accounts, so it has to be
    # habit rather than a later audit.
    def notes   = current_user.notes
    def folders = current_user.folders
    def entries = current_user.day_entries
    def logs    = current_user.day_logs
end
