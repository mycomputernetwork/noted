# Milestone 1 smoke test. Proves the stack boots, the schema is right, the
# scoping stub resolves a user, and the Day/Year composers assemble.
#
# Milestone 2 replaces this route with the tiled board.
class HomeController < ApplicationController
  def index
    @user = current_user
    @notes = notes.kept.by_edited.limit(5)
    @folders = folders.ordered
    @year = Year.for(user: @user)
    @today = @year.days.find(&:today?)
  end
end
