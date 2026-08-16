class ApplicationController < ActionController::Base
  include Authentication

  allow_browser versions: :modern

  # Skip on turbo-frame and JSON requests, so the tree isn't built and thrown
  # away on every autosave.
  before_action :load_tree, if: :renders_sidebar?

  private
    def renders_sidebar?
      request.get? && request.format.html? && !turbo_frame_request?
    end

    def load_tree
      @tree = Tree.for(user: current_user)
    end

    # Every query originates from current_user; nothing is loaded by bare id
    # from a global scope. This is the isolation model between accounts.
    def notes   = current_user.notes
    def folders = current_user.folders
    def entries = current_user.day_entries
    def logs    = current_user.day_logs
end
