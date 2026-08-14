Rails.application.config.after_initialize do
  # Blobs are only ever reachable through their parent note, and a note is
  # only ever loaded through current_user (PRD §5, scoping rule). Signed IDs
  # expire so a leaked URL is not permanent.
  ActiveStorage.urls_expire_in = 1.hour
end
