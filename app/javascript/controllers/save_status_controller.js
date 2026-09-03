import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status"]

  connect() {
    this.pending = new Set()
  }

  saving({ detail: { requestId } }) {
    clearTimeout(this.timer)
    this.pending.add(requestId)
    this.show("Saving…")
  }

  saved({ detail: { requestId } }) {
    this.pending.delete(requestId)
    if (this.pending.size > 0) return this.show("Saving…")

    this.show("Saved")
    this.timer = setTimeout(() => { this.statusTarget.hidden = true }, 1500)
  }

  failed({ detail: { requestId, message } }) {
    this.pending.delete(requestId)
    clearTimeout(this.timer)
    this.show(message)
  }

  show(message) {
    this.statusTarget.textContent = message
    this.statusTarget.hidden = false
  }
}
