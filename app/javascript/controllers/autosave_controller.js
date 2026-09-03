import { Controller } from "@hotwired/stimulus"
import { formHeaders } from "request"

// Autosave: debounced ~800ms, immediate on blur/close. Knows nothing about its
// surface — given a form and, once the record exists, an update URL.
export default class extends Controller {
  static targets = ["form", "status"]
  static values = {
    url: String,            // empty until the record exists
    delay: { type: Number, default: 800 }
  }

  connect() {
    this.queuedPayload = this.serialize()
    this.queue = Promise.resolve()
    this.finalized = false

    this.attempts = 0

    this.flushOnUnload = () => this.save({ keepalive: true })
    addEventListener("beforeunload", this.flushOnUnload)
    // Turbo navigations don't unload the page, so they need their own hook.
    addEventListener("turbo:before-visit", this.flushOnUnload)

    this.retryNow = () => { if (this.attempts > 0) this.save() }
    addEventListener("online", this.retryNow)
  }

  disconnect() {
    removeEventListener("beforeunload", this.flushOnUnload)
    removeEventListener("turbo:before-visit", this.flushOnUnload)
    removeEventListener("online", this.retryNow)
    clearTimeout(this.timer)
    clearTimeout(this.retryTimer)

    // Torn off the page without a close (a Turbo frame swap): flush without
    // awaiting, or the last edit is dropped.
    if (!this.finalized) this.save({ keepalive: true })
  }

  begin(url, id) {
    clearTimeout(this.timer)
    clearTimeout(this.retryTimer)
    this.urlValue = url
    this.recordId = id
    this.queuedPayload = this.serialize()
    this.finalized = false
    this.finalizing = false
    this.attempts = 0
    this.status("")
  }

  schedule() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.save(), this.delayValue)
  }

  saveNow() {
    clearTimeout(this.timer)
    return this.save()
  }

  preventSubmit(event) {
    event.preventDefault()
  }

  async finalize() {
    this.finalized = true
    this.finalizing = true
    clearTimeout(this.timer)
    if (this.recordId) this.dispatch("preview", { detail: { id: this.recordId, attributes: this.attributes() } })

    await this.save()
    if (this.attempts > 0) return

    await this.discardIfEmpty()
    this.finalizing = false
    this.dispatch("finalized")
  }

  save({ keepalive = false } = {}) {
    const payload = this.serialize()

    if (payload === this.queuedPayload) return this.queue
    // A folder or pin on a note with no title and no body is not a note.
    if (!this.urlValue && !this.hasContent()) return this.queue

    this.queuedPayload = payload
    this.status("Saving…")
    const requestId = crypto.randomUUID()
    this.dispatch("saving", { detail: { requestId, id: this.recordId } })

    // Chained, never parallel: request order is response order.
    this.queue = this.queue
      .then(() => this.send(payload, keepalive, requestId))
      .catch((error) => this.failed(error, requestId))

    return this.queue
  }

  async send(payload, keepalive, requestId) {
    const creating = !this.urlValue

    const response = await fetch(creating ? this.formTarget.action : this.urlValue, {
      method: creating ? "POST" : "PATCH",
      headers: formHeaders(),
      body: payload,
      keepalive
    })

    if (!response.ok) throw new Error(`save failed: ${response.status}`)

    this.attempts = 0
    clearTimeout(this.retryTimer)

    const persistedNote = await response.json()
    // An earlier request can finish after the form has moved on.
    const dirty = payload !== this.serialize()
    const note = dirty
      ? { ...persistedNote, ...this.attributes(), updated_at: new Date().toISOString() }
      : persistedNote

    this.urlValue = persistedNote.url
    this.recordId = persistedNote.id
    this.status(dirty ? "Saving…" : "Saved")

    // Turbo drops its snapshot cache after a form submission. These writes go
    // out through fetch, so nothing else does it, and a back navigation would
    // restore a board still showing the note as it was.
    Turbo.cache.clear()

    this.dispatch("saved", { detail: { note, requestId, dirty } })
  }

  // The server refuses to discard a note with content, so this only removes a
  // record that was created and then emptied out.
  async discardIfEmpty() {
    if (!this.urlValue || this.hasContent()) return

    await fetch(this.urlValue, { method: "DELETE", headers: formHeaders() })

    Turbo.cache.clear()
    const id = this.recordId
    this.urlValue = ""
    this.recordId = null
    this.dispatch("discarded", { detail: { id } })
  }

  // Backs off to 30s, re-reading the form rather than replaying the failed
  // payload, so it sends whatever has been typed since.
  failed(error, requestId) {
    // Force the next attempt through the payload comparison in save().
    this.queuedPayload = null
    this.attempts += 1

    const delay = Math.min(1000 * 2 ** (this.attempts - 1), 30000)
    const message = `Not saved — retrying in ${Math.round(delay / 1000)}s`
    this.status(message)
    this.dispatch("failed", { detail: { requestId, message } })

    clearTimeout(this.retryTimer)
    this.retryTimer = setTimeout(() => this.finalizing ? this.finalize() : this.save(), delay)

    console.error("[autosave]", error)
  }

  serialize() {
    return new URLSearchParams(new FormData(this.formTarget)).toString()
  }

  attributes() {
    return {
      title: this.formTarget.elements["note[title]"]?.value || "",
      body: this.formTarget.elements["note[body]"]?.value || "",
      folder_id: this.formTarget.elements["note[folder_id]"]?.value || null,
      pinned: this.formTarget.elements["note[pinned]"][1]?.checked || false
    }
  }

  // Only title/body here; images are checked server-side in Note#empty?.
  hasContent() {
    return ["title", "body"].some((field) => {
      const input = this.formTarget.elements[`note[${field}]`]
      return input && input.value.trim().length > 0
    })
  }

  status(text) {
    if (this.hasStatusTarget) this.statusTarget.textContent = text
  }
}
