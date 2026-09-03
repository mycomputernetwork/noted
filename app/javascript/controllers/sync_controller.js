import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"
import { clientId } from "sync_client"

export default class extends Controller {
  connect() {
    this.heldNotes = new Set()
    this.consumer = createConsumer()
    this.subscription = this.consumer.subscriptions.create("SyncChannel", {
      received: message => this.received(message)
    })

    this.drop = () => clearTimeout(this.timer)
    addEventListener("turbo:visit", this.drop)
  }

  disconnect() {
    removeEventListener("turbo:visit", this.drop)
    clearTimeout(this.timer)
    this.subscription?.unsubscribe()
    this.consumer?.disconnect()
  }

  received({ type, id, client }) {
    if (client === clientId) return

    if (type === "note" && this.board) {
      if (this.editing(id)) this.heldNotes.add(id)
      else this.fetchNote(id)
      return
    }

    if (this.editing()) this.heldRefresh = true
    else this.repaintSoon()
  }

  flush() {
    this.heldNotes.forEach(id => this.fetchNote(id))
    this.heldNotes.clear()

    if (this.heldRefresh && !this.leaving) this.repaintSoon()
    this.heldRefresh = false
  }

  hold() {
    this.leaving = true
  }

  repaint() {
    if (!this.leaving) Turbo.visit(window.location.href, { action: "replace" })
  }

  repaintSoon() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.repaint(), 300)
  }

  async fetchNote(id) {
    try {
      const response = await fetch(`/api/v1/notes/${encodeURIComponent(id)}`, {
        headers: { Accept: "application/json" }
      })
      if (!response.ok && response.status !== 404) throw new Error(`sync failed: ${response.status}`)

      const detail = response.ok ? { note: await response.json(), id } : { id }
      this.board?.dispatchEvent(new CustomEvent("sync:note", { bubbles: true, detail }))
    } catch (error) {
      console.error("[sync]", error)
    }
  }

  editing(id) {
    const dialog = document.querySelector("dialog.modal[open]")
    if (!dialog) return false
    return !id || dialog.dataset.noteId === id
  }

  get board() {
    return document.querySelector("[data-controller~='board']")
  }
}
