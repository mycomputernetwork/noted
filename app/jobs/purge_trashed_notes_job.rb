# Trash is a soft delete with a 30-day purge. This is the only place in the
# application that destroys anything irrecoverably.
class PurgeTrashedNotesJob < ApplicationJob
  queue_as :background

  def perform(retention: Rails.configuration.x.trash_retention)
    cutoff = retention.ago

    # destroy_all rather than delete_all: Active Storage attachments have to be
    # purged with the note, and delete_all would orphan the blobs on disk.
    purged_notes = Note.where(deleted_at: ...cutoff).destroy_all.size

    purged_entries = DayEntry.where(deleted_at: ...cutoff).delete_all

    Rails.logger.info(
      "[purge] removed #{purged_notes} notes and #{purged_entries} day entries " \
      "deleted before #{cutoff.to_date}"
    )
  end
end
