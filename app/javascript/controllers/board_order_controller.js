import { Controller } from "@hotwired/stimulus"
import { jsonHeaders } from "request"

export default class extends Controller {
  static values = { url: String }

  start(event) {
    const card = event.target.closest(".card[data-note-id]")
    if (!card || !this.element.contains(card)) return

    this.source = card
    this.original = { parent: card.parentNode, next: card.nextSibling }
    this.moved = false
    this.submitted = false
  }

  over(event) {
    if (!this.source) return

    if (this.moved) {
      event.preventDefault()
      event.dataTransfer.dropEffect = "move"
    }

    const target = event.target.closest(".card[data-note-id]")
    if (!target || target === this.source || target.dataset.pinned !== this.source.dataset.pinned) return

    event.preventDefault()
    event.dataTransfer.dropEffect = "move"

    const reference = this.after(target, event) ? target.nextSibling : target
    if (reference === this.source || this.source.nextSibling === reference) return

    this.moveWithAnimation(target.closest(".masonry"), reference)
  }

  drop(event) {
    if (!this.source || !this.moved) return

    event.preventDefault()
    this.submit()
  }

  end() {
    if (!this.source) return
    if (this.moved) this.submit()
    else this.reset()
  }

  async submit() {
    if (!this.source || !this.moved || this.submitted) return

    this.submitted = true
    const source = this.source
    const original = this.original
    const ids = Array.from(this.element.querySelectorAll(".card[data-note-id]"))
      .map(card => card.dataset.noteId)

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        headers: jsonHeaders(),
        body: JSON.stringify({ note_ids: ids, folder_id: this.element.dataset.folderId || null })
      })

      if (!response.ok) throw new Error(`board reorder failed: ${response.status}`)
      this.dispatch("reordered", { detail: { notes: await response.json() } })
    } catch (error) {
      this.undo(source, original)
      console.error("[board-order]", error)
    } finally {
      if (this.source === source) this.reset()
    }
  }

  reset() {
    this.source = null
    this.original = null
    this.moved = false
    this.submitted = false
  }

  after(card, event) {
    const bounds = card.getBoundingClientRect()
    const sameRow = Math.abs(event.clientY - (bounds.top + bounds.height / 2)) < bounds.height / 3
    if (sameRow) return event.clientX > bounds.left + bounds.width / 2

    return event.clientY > bounds.top + bounds.height / 2
  }

  moveWithAnimation(grid, reference) {
    const cards = Array.from(grid?.querySelectorAll(".card[data-note-id]") ?? [])
    const before = new Map(cards.map(card => [card, card.getBoundingClientRect()]))

    grid.insertBefore(this.source, reference)
    this.moved = true
    this.layout(grid)

    requestAnimationFrame(() => {
      cards.forEach(card => this.animateCard(card, before.get(card)))
    })
  }

  animateCard(card, before) {
    if (!before || card === this.source) return

    const after = card.getBoundingClientRect()
    const dx = before.left - after.left
    const dy = before.top - after.top
    if (Math.abs(dx) < 1 && Math.abs(dy) < 1) return

    card.animate(
      [
        { transform: `translate(${dx}px, ${dy}px)` },
        { transform: "translate(0, 0)" }
      ],
      { duration: 160, easing: "cubic-bezier(0.2, 0, 0, 1)" }
    )
  }

  undo(source, original) {
    if (!source || !original?.parent) return

    original.parent.insertBefore(source, original.next)
    this.layout(original.parent)
  }

  layout(grid) {
    if (!grid) return

    const masonry = this.application.getControllerForElementAndIdentifier(grid, "masonry")
    masonry ? masonry.layout() : grid.offsetHeight
  }
}
