import { Controller } from "@hotwired/stimulus"
import { clientId } from "sync_client"

// Autosave: no save button, debounced ~800ms, immediate on blur/close. Knows
// nothing about its surface — given a form, a create URL and an update URL.
export default class extends Controller {
  static targets = ["form", "status"]
  static values = {
    createUrl: String,
    url: String,            // empty until the record exists
    delay: { type: Number, default: 800 }
  }

  connect() {
    // A save matching what's already on disk is skipped, so a blur right after
    // a debounced save doesn't fire a second identical request.
    this.saved = this.serialize()
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

  // --- Entry points -------------------------------------------------------

  schedule() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.save(), this.delayValue)
  }

  saveNow() {
    clearTimeout(this.timer)
    return this.save()
  }

  async finalize() {
    this.finalized = true
    clearTimeout(this.timer)

    await this.save()
    await this.discardIfEmpty()

    this.dispatch("finalized")
  }

  // --- Saving -------------------------------------------------------------

  save({ keepalive = false } = {}) {
    const payload = this.serialize()

    if (payload === this.saved) return this.queue
    // A folder or pin on a note with no title and no body is not a note.
    if (!this.urlValue && !this.hasContent()) return this.queue

    this.saved = payload
    this.status("Saving…")

    // Chained, never parallel: request order is response order.
    this.queue = this.queue
      .then(() => this.send(payload, keepalive))
      .catch((error) => this.failed(error))

    return this.queue
  }

  async send(payload, keepalive) {
    const creating = !this.urlValue

    const response = await fetch(creating ? this.createUrlValue : this.urlValue, {
      method: creating ? "POST" : "PATCH",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "Accept": "application/json",
        "X-CSRF-Token": this.csrfToken,
        "X-Client-Id": clientId
      },
      body: payload,
      keepalive
    })

    if (!response.ok) throw new Error(`save failed: ${response.status}`)

    this.attempts = 0
    clearTimeout(this.retryTimer)

    const note = await response.json()

    // First save persists the note; every save after is a PATCH to this URL.
    this.urlValue = note.url
    this.status("Saved")
    this.dispatch("saved", { detail: { note } })
  }

  // The server refuses to discard a note with content, so this only removes a
  // record that was created and then emptied out.
  async discardIfEmpty() {
    if (!this.urlValue || this.hasContent()) return

    await fetch(this.urlValue, {
      method: "DELETE",
      headers: { "X-CSRF-Token": this.csrfToken, "Accept": "application/json", "X-Client-Id": clientId }
    })

    this.urlValue = ""
    this.dispatch("discarded")
  }

  // Back off and retry to 30s. Re-reads the form rather than replaying the
  // failed payload, so it sends whatever has been typed since.
  failed(error) {
    // Force the next attempt to send rather than match a payload that never landed.
    this.saved = null
    this.attempts += 1

    const delay = Math.min(1000 * 2 ** (this.attempts - 1), 30000)
    this.status(`Not saved — retrying in ${Math.round(delay / 1000)}s`)

    clearTimeout(this.retryTimer)
    this.retryTimer = setTimeout(() => this.save(), delay)

    console.error("[autosave]", error)
  }

  // --- Reading the form ---------------------------------------------------

  serialize() {
    return new URLSearchParams(new FormData(this.formTarget)).toString()
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

  get csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content
  }
}
