// Identifies this tab on every write it makes. SyncChannel echoes it back in
// the broadcast, so a tab never reloads the page over an edit of its own.
export const clientId = crypto.randomUUID()
