import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  start(event) {
    const card = event.target.closest(".card[data-note-id]")
    if (!card || !this.element.contains(card)) return

    this.source = card
    this.original = { parent: card.parentNode, next: card.nextSibling }
    this.moved = false
    this.dropPending = false
  }

  over(event) {
    if (!this.source) return

    const target = event.target.closest(".card[data-note-id]")
    if (!target || target === this.source || target.dataset.pinned !== this.source.dataset.pinned) return

    event.preventDefault()
    event.dataTransfer.dropEffect = "move"

    const after = this.after(target, event)
    target.parentNode.insertBefore(this.source, after ? target.nextSibling : target)
    this.moved = true
    this.layout(target.closest(".masonry"))
  }

  async drop(event) {
    if (!this.source || !this.moved) return

    event.preventDefault()
    this.dropPending = true
    const ids = Array.from(this.element.querySelectorAll(".card[data-note-id]"))
      .map(card => card.dataset.noteId)

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        headers: this.headers,
        body: JSON.stringify({ note_ids: ids, folder_id: this.element.dataset.folderId || null })
      })

      if (!response.ok) throw new Error(`board reorder failed: ${response.status}`)
    } catch (error) {
      this.undo()
      console.error("[board-order]", error)
    } finally {
      this.dropPending = false
      this.reset()
    }
  }

  end() {
    if (this.dropPending) return
    if (this.moved) this.undo()

    this.reset()
  }

  reset() {
    this.source = null
    this.original = null
    this.moved = false
    this.dropPending = false
  }

  after(card, event) {
    const bounds = card.getBoundingClientRect()
    const sameRow = Math.abs(event.clientY - (bounds.top + bounds.height / 2)) < bounds.height / 3
    if (sameRow) return event.clientX > bounds.left + bounds.width / 2

    return event.clientY > bounds.top + bounds.height / 2
  }

  undo() {
    if (!this.source || !this.original?.parent) return

    this.original.parent.insertBefore(this.source, this.original.next)
    this.layout(this.original.parent)
  }

  layout(grid) {
    if (!grid) return

    this.application.getControllerForElementAndIdentifier(grid, "masonry")?.scheduleLayout()
  }

  get headers() {
    return {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "X-CSRF-Token": this.csrfToken
    }
  }

  get csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content
  }
}
