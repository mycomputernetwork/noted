module Scoped
  extend ActiveSupport::Concern

  private
    def notes = current_user.notes
    def folders = current_user.folders
    def entries = current_user.day_entries
    def logs = current_user.day_logs
end
