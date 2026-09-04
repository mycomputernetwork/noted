module Scoped
  extend ActiveSupport::Concern

  private
    def notes = current_user.notes
    def folders = current_user.folders
    def year_docs = current_user.year_docs
end
