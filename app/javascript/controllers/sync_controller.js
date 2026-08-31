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
    if (this.pending) return
    this.pending = true
    setTimeout(() => {
      this.pending = false
      
      const editor = document.querySelector("turbo-frame#editor")
      const composer = document.querySelector("turbo-frame#composer")
      const editorOpen = editor?.querySelector("dialog[open]")
      const composerOpen = composer?.querySelector(".composer--open")
      
      if (editorOpen || composerOpen) {
        if (editorOpen) editor.setAttribute("data-turbo-permanent", "")
        if (composerOpen) composer.setAttribute("data-turbo-permanent", "")
        
        const afterMorph = () => {
          if (editorOpen && editor.src) {
            editor.reload()
            editor.removeAttribute("data-turbo-permanent")
          }
          if (composerOpen && composer.src) {
            composer.reload()
            composer.removeAttribute("data-turbo-permanent")
          }
        }
        
        addEventListener("turbo:render", afterMorph, { once: true })
      }
      
      Turbo.visit(window.location.href, { action: "replace" })
    }, 300)
  }
}
