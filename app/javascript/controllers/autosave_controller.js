import { Controller } from "@hotwired/stimulus"
import NoteEditSession from "note_edit_session"
import { formHeaders } from "request"

export default class extends Controller {
  static targets = ["form", "status"]
  static values = {
    url: String,
    delay: { type: Number, default: 800 }
  }

  connect() {
    this.session = new NoteEditSession(this.snapshot())
    this.queue = Promise.resolve()
    this.finalized = false
    this.attempts = 0

    this.flushOnUnload = () => this.save({ keepalive: true })
    addEventListener("beforeunload", this.flushOnUnload)
    addEventListener("turbo:before-visit", this.flushOnUnload)

    this.retryNow = () => { if (this.attempts > 0) this.retry() }
    addEventListener("online", this.retryNow)
  }

  disconnect() {
    removeEventListener("beforeunload", this.flushOnUnload)
    removeEventListener("turbo:before-visit", this.flushOnUnload)
    removeEventListener("online", this.retryNow)
    clearTimeout(this.timer)
    clearTimeout(this.retryTimer)

    if (!this.finalized) this.save({ keepalive: true })
  }

  begin(note) {
    clearTimeout(this.timer)
    clearTimeout(this.retryTimer)
    this.urlValue = note.url
    this.recordId = note.id
    this.session.reset(this.snapshot(), note)
    this.finalized = false
    this.finalizing = false
    this.attempts = 0
    this.status("")
  }

  schedule() {
    this.session.update(this.snapshot())
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.save(), this.delayValue)
  }

  saveNow() {
    this.session.update(this.snapshot())
    clearTimeout(this.timer)
    return this.save()
  }

  preventSubmit(event) {
    event.preventDefault()
  }

  async finalize() {
    if (this.finalizing) return

    this.finalizing = true
    this.session.update(this.snapshot())
    clearTimeout(this.timer)

    const note = this.session.current()
    if (note) this.dispatch("preview", { detail: { note } })

    await this.save()
    await this.finishFinalizing()
  }

  save({ keepalive = false } = {}) {
    this.session.update(this.snapshot())
    if (!this.urlValue && !this.hasContent()) return this.queue

    const request = this.session.nextRequest()
    if (!request) return this.queue

    const requestId = crypto.randomUUID()
    this.status("Saving…")
    this.dispatch("saving", { detail: { requestId, id: this.recordId } })

    this.queue = this.queue
      .then(() => this.send(request, keepalive, requestId))
      .catch(error => this.failed(error, request, requestId))

    return this.queue
  }

  async send(request, keepalive, requestId) {
    const creating = !this.urlValue
    const response = await fetch(creating ? this.formTarget.action : this.urlValue, {
      method: creating ? "POST" : "PATCH",
      headers: formHeaders(),
      body: request.payload,
      keepalive
    })

    if (!response.ok) throw new Error(`save failed: ${response.status}`)

    this.attempts = 0
    clearTimeout(this.retryTimer)

    const persistedNote = await response.json()
    const { note, dirty } = this.session.acknowledge(request, persistedNote)
    this.urlValue = persistedNote.url
    this.recordId = persistedNote.id
    this.status(dirty ? "Saving…" : "Saved")

    Turbo.cache.clear()
    this.dispatch("saved", { detail: { note, requestId, dirty } })
  }

  async finishFinalizing() {
    if (this.attempts > 0 || this.finalized) return

    await this.discardIfEmpty()
    this.finalized = true
    this.finalizing = false
    this.dispatch("finalized")
  }

  async retry() {
    await this.save()
    if (this.finalizing) await this.finishFinalizing()
  }

  async discardIfEmpty() {
    if (!this.urlValue || this.hasContent()) return

    await fetch(this.urlValue, { method: "DELETE", headers: formHeaders() })

    Turbo.cache.clear()
    const id = this.recordId
    this.urlValue = ""
    this.recordId = null
    this.dispatch("discarded", { detail: { id } })
  }

  failed(error, request, requestId) {
    this.session.fail(request)
    this.attempts += 1

    const delay = Math.min(1000 * 2 ** (this.attempts - 1), 30000)
    const message = `Not saved — retrying in ${Math.round(delay / 1000)}s`
    this.status(message)
    this.dispatch("failed", { detail: { requestId, message } })

    clearTimeout(this.retryTimer)
    this.retryTimer = setTimeout(() => this.retry(), delay)
    console.error("[autosave]", error)
  }

  snapshot() {
    return {
      payload: new URLSearchParams(new FormData(this.formTarget)).toString(),
      attributes: {
        title: this.formTarget.elements["note[title]"]?.value || "",
        body: this.formTarget.elements["note[body]"]?.value || "",
        folder_id: this.formTarget.elements["note[folder_id]"]?.value || null,
        pinned: this.formTarget.elements["note[pinned]"][1]?.checked || false
      }
    }
  }

  hasContent() {
    return ["title", "body"].some(field => {
      const input = this.formTarget.elements[`note[${field}]`]
      return input && input.value.trim().length > 0
    })
  }

  status(text) {
    if (this.hasStatusTarget) this.statusTarget.textContent = text
  }
}
