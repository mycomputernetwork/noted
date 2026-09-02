import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"
import { clientId } from "sync_client"

// Keeps the board level with the notes: it repaints when an editor here closes,
// and when another client writes. Both go through one morphing visit of the
// page's own URL. Attach to the shell, so it lives for the whole session.
export default class extends Controller {
  connect() {
    this.consumer = createConsumer()
    this.subscription = this.consumer.subscriptions.create("SyncChannel", {
      received: ({ client }) => this.received(client)
    })

    // Any navigation renders the board fresh, so a queued repaint would only
    // fight the page already on its way — the modal's expand, most of all.
    this.drop = () => clearTimeout(this.timer)
    addEventListener("turbo:visit", this.drop)
  }

  disconnect() {
    removeEventListener("turbo:visit", this.drop)
    clearTimeout(this.timer)
    this.subscription?.unsubscribe()
    this.consumer?.disconnect()
  }

  // autosave:finalized — an editor has saved and closed. The note it wrote
  // belongs on the board, and the composer belongs closed; the board's own
  // markup is both.
  flush() {
    clearTimeout(this.timer)
    if (this.leaving) return

    this.repaint()
  }

  // modal:expand — the tab is on its way to the note's own page, and that visit
  // is the repaint. A second one to the board would start after it and land
  // after it too.
  hold() {
    this.leaving = true
  }

  // A write echoes the tab that made it. Refreshing on your own echo closes the
  // composer you are typing into, which is what the board is for.
  received(client) {
    if (client === clientId) return

    clearTimeout(this.timer)
    this.timer = setTimeout(() => {
      // An open editor is not in the board's markup, so the morph would take it
      // mid-sentence. Closing it repaints anyway, through flush.
      if (this.editing) return

      this.repaint()
    }, 300)
  }

  repaint() {
    Turbo.visit(window.location.href, { action: "replace" })
  }

  get editing() {
    return document.querySelector("turbo-frame#editor dialog[open], .composer--open")
  }
}
