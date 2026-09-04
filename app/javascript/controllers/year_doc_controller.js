import { Controller } from "@hotwired/stimulus"
import { formHeaders } from "request"

export default class extends Controller {
  static targets = ["form", "status"]
  static values = { delay: { type: Number, default: 800 } }

  connect() {
    this.input.value = this.input.defaultValue
    this.saved = this.input.value
    this.queue = Promise.resolve()
    this.flush = () => this.save()
    addEventListener("beforeunload", this.flush)
    addEventListener("turbo:before-visit", this.flush)
  }

  disconnect() {
    removeEventListener("beforeunload", this.flush)
    removeEventListener("turbo:before-visit", this.flush)
    clearTimeout(this.timer)
    this.save()
  }

  schedule() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.save(), this.delayValue)
  }

  save() {
    const body = this.snapshot()
    if (body === this.saved) return this.queue

    this.status("Saving…")
    this.queue = this.queue.then(() => this.send(body)).catch(() => this.status("Not saved"))
    return this.queue
  }

  async send(body) {
    const payload = new URLSearchParams()
    payload.set("year_doc[body]", body)

    const response = await fetch(this.formTarget.action, {
      method: "PATCH",
      headers: formHeaders(),
      body: payload.toString(),
      keepalive: true
    })

    if (!response.ok) throw new Error(`save failed: ${response.status}`)
    const data = await response.json()
    this.saved = data.body
    this.status(data.persisted ? "Saved" : "")
  }

  snapshot() {
    return this.input.value
  }

  get input() {
    return this.formTarget.elements["year_doc[body]"]
  }

  status(text) {
    if (this.hasStatusTarget) this.statusTarget.textContent = text
  }
}
