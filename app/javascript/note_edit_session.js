export default class NoteEditSession {
  constructor(snapshot, note = null) {
    this.reset(snapshot, note)
  }

  reset(snapshot, note = null) {
    this.persisted = note
    this.persistedPayload = snapshot.payload
    this.draft = snapshot
    this.revision = 0
    this.queuedRevision = 0
  }

  update(snapshot) {
    if (snapshot.payload === this.draft.payload) return

    this.draft = snapshot
    this.revision += 1
  }

  nextRequest() {
    if (this.revision === this.queuedRevision) return null

    this.queuedRevision = this.revision
    return {
      payload: this.draft.payload,
      revision: this.revision
    }
  }

  acknowledge(request, note) {
    this.persisted = note
    this.persistedPayload = request.payload
    const dirty = request.revision !== this.revision
    return { note: dirty ? this.current() : note, dirty }
  }

  fail(request) {
    if (request.revision === this.queuedRevision) this.queuedRevision = null
  }

  current() {
    if (!this.persisted) return null
    if (this.draft.payload === this.persistedPayload) return this.persisted

    return {
      ...this.persisted,
      ...this.draft.attributes,
      updated_at: new Date().toISOString()
    }
  }
}
