class ApplicationController < ActionController::Base
  include Authentication
  include Scoped
  include SyncOrigin

  allow_browser versions: :modern

  # Skip on turbo-frame and JSON requests, so the tree isn't built and thrown
  # away on every autosave.
  before_action :load_tree, if: :renders_sidebar?

  private
    def renders_sidebar?
      signed_in? && request.get? && !request.format.json? && !turbo_frame_request?
    end

    def load_tree
      @tree = Tree.for(user: current_user)
    end

end
