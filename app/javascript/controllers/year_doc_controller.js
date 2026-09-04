import { Controller } from "@hotwired/stimulus"
import { formHeaders } from "request"

export default class extends Controller {
  static targets = ["form", "status"]
  static values = { delay: { type: Number, default: 800 } }

  connect() {
    this.saved = this.snapshot()
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
    this.queue = this.queue.then(() => this.send()).catch(() => this.status("Not saved"))
    return this.queue
  }

  async send() {
    const response = await fetch(this.formTarget.action, {
      method: "PATCH",
      headers: formHeaders(),
      body: new URLSearchParams(new FormData(this.formTarget)).toString(),
      keepalive: true
    })

    if (!response.ok) throw new Error(`save failed: ${response.status}`)
    const data = await response.json()
    this.saved = data.body
    this.status(data.persisted ? "Saved" : "")
  }

  snapshot() {
    return this.formTarget.elements["year_doc[body]"].value
  }

  status(text) {
    if (this.hasStatusTarget) this.statusTarget.textContent = text
  }
}
