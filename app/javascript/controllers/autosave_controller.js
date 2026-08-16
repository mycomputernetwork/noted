import { Controller } from "@hotwired/stimulus"

// Autosave.
//
// Saving is implicit: there is no save button anywhere in this application.
// Typing stops, ~800ms passes, the note is on disk. Leaving a field or
// closing the surface saves immediately rather than waiting out the timer.
//
// This controller knows nothing about the surface it is mounted on. It is
// given a form, a create URL and (once the record exists) an update URL, and
// it deals only in those. The modal supplies a <dialog> frame around it;
// milestone 4's full-pane note supplies a page instead, and must be able to
// mount this file unchanged — that reuse is the test of whether it was built
// as a standalone thing or quietly welded to the modal.
//
// Three rules it exists to enforce:
//
// 1. A record is created on the first keystroke, not when the surface is
// focused. Opening the editor and walking away writes nothing.
// 2. Saves never overlap. Every request is chained behind the one before
// it, so a slow response cannot land after a newer one and resurrect
// stale text.
// 3. No interaction loses data. Closing, navigating away and unloading all
// flush first; the unload path uses `keepalive` so the request outlives
// the page, and a failed save retries on its own rather than waiting for
// the next keystroke to carry it.
export default class extends Controller {
  static targets = ["form", "status"]
  static values = {
    createUrl: String,
    url: String,            // empty until the record exists
    delay: { type: Number, default: 800 }
  }

  connect() {
    // What is already on disk. A save that would send exactly this is
    // skipped, which is what stops a blur immediately after a debounced
    // save from issuing a second identical request.
    this.saved = this.serialize()
    this.queue = Promise.resolve()
    this.finalized = false

    this.attempts = 0

    this.flushOnUnload = () => this.save({ keepalive: true })
    addEventListener("beforeunload", this.flushOnUnload)
    // Turbo navigations do not unload the page, so they need their own hook.
    addEventListener("turbo:before-visit", this.flushOnUnload)

    // Coming back online is better information than any backoff timer.
    this.retryNow = () => { if (this.attempts > 0) this.save() }
    addEventListener("online", this.retryNow)
  }

  disconnect() {
    removeEventListener("beforeunload", this.flushOnUnload)
    removeEventListener("turbo:before-visit", this.flushOnUnload)
    removeEventListener("online", this.retryNow)
    clearTimeout(this.timer)
    clearTimeout(this.retryTimer)

    // Torn off the page without a close (a Turbo frame swap, say). Fire the
    // last save without waiting for it — the alternative is dropping it.
    if (!this.finalized) this.save({ keepalive: true })
  }

  // --- Entry points -------------------------------------------------------

  // input -> every keystroke. Debounced.
  schedule() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.save(), this.delayValue)
  }

  // blur, and change on the folder select and the pin toggle: deliberate
  // acts, saved without the wait.
  saveNow() {
    clearTimeout(this.timer)
    return this.save()
  }

  // Called when the surface closes. Flushes, then discards the record if the
  // editor was opened, typed into and emptied out again, and finally
  // announces that it is done so the surface can tear itself down knowing
  // nothing is in flight.
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
    // Nothing typed yet means nothing to create. A folder or a pin on a note
    // that has no title and no body is not a note.
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
        "X-CSRF-Token": this.csrfToken
      },
      body: payload,
      keepalive
    })

    if (!response.ok) throw new Error(`save failed: ${response.status}`)

    this.attempts = 0
    clearTimeout(this.retryTimer)

    const note = await response.json()

    // The first successful save turns a new note into a persisted one; every
    // save after it is a PATCH to the URL the server just handed back.
    this.urlValue = note.url
    this.status("Saved")
    this.dispatch("saved", { detail: { note } })
  }

  // A note that was created and then emptied out again should not survive
  // the editor closing. The server refuses to discard anything that still
  // has content in it, so this can only ever remove a blank record.
  async discardIfEmpty() {
    if (!this.urlValue || this.hasContent()) return

    await fetch(this.urlValue, {
      method: "DELETE",
      headers: { "X-CSRF-Token": this.csrfToken, "Accept": "application/json" }
    })

    this.urlValue = ""
    this.dispatch("discarded")
  }

  // A save can fail because the server is down, because the tailnet dropped,
  // or because the laptop lid was closed mid-request. None of those are the
  // user's problem to solve, and none of them should quietly wait for the
  // next keystroke — which is what a status line reading "retrying" would be
  // promising while doing nothing.
  //
  // So: back off and try again, doubling from a second up to thirty, until it
  // lands or the surface goes away. The retry re-reads the form rather than
  // replaying the failed payload, so it sends whatever has been typed since.
  failed(error) {
    // Force the next attempt to send rather than compare equal to a payload
    // that never landed.
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

  // Title and body are the note. Milestone 5 adds images, which live on the
  // server side of `Note#empty?` — the discard endpoint checks there too, so
  // a note that is blank here but carries an image is refused, not lost.
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
