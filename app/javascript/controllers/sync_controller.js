import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

// Subscribes to SyncChannel and morphs the page when another client writes.
// Attach to the shell element so it lives for the whole session.
export default class extends Controller {
  connect() {
    this.consumer = createConsumer()
    this.subscription = this.consumer.subscriptions.create("SyncChannel", {
      received: () => this.refresh()
    })
    this.pending = false
  }

  disconnect() {
    this.subscription?.unsubscribe()
    this.consumer?.disconnect()
  }

  refresh() {
    // Debounce rapid-fire broadcasts (e.g. autosave + folder change)
    if (this.pending) return
    this.pending = true
    setTimeout(() => {
      this.pending = false
      // Turbo morph: re-fetches the current URL and patches the DOM.
      Turbo.visit(window.location.href, { action: "replace" })
    }, 300)
  }
}
