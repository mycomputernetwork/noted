import { Controller } from "@hotwired/stimulus"
import { formHeaders } from "request"

export default class extends Controller {
  static targets = ["status"]
  static values = { emptyUrl: String }

  restore(event) {
    const card = event.target.closest(".trash-card[data-note-url]")
    if (card) this.write(`${card.dataset.noteUrl}/restore`, "PATCH")
  }

  purge(event) {
    const card = event.target.closest(".trash-card[data-note-url]")
    if (!card || !confirm("Delete this note forever?")) return

    this.write(`${card.dataset.noteUrl}/purge`, "DELETE")
  }

  empty() {
    if (!confirm("Delete every note in trash forever?")) return

    this.write(this.emptyUrlValue, "DELETE")
  }

  async write(url, method) {
    try {
      const response = await fetch(url, { method, headers: formHeaders() })
      if (!response.ok) throw new Error(`trash write failed: ${response.status}`)
      Turbo.visit(location.href, { action: "replace" })
    } catch (error) {
      this.statusTarget.textContent = "Couldn’t update trash."
      this.statusTarget.hidden = false
      console.error("[trash]", error)
    }
  }
}
