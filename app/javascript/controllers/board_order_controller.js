import { Controller } from "@hotwired/stimulus"
import { jsonHeaders } from "request"

const SHUFFLE_MS = 240

export default class extends Controller {
  static values = { url: String }

  start(event) {
    const card = event.target.closest(".card[data-note-id]")
    if (!card || !this.element.contains(card)) return

    // A shuffle from the drag before this one may still be playing, and its
    // cards would measure where they are rather than where they belong.
    this.animations?.forEach(animation => animation.cancel())

    this.source = card
    this.grid = card.closest(".masonry")
    this.original = { parent: card.parentNode, next: card.nextElementSibling }
    this.moved = false
    this.submitted = false
    this.slots = this.measure()
  }

  over(event) {
    if (!this.source) return

    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
    this.place(event)
  }

  drop(event) {
    if (!this.source) return

    event.preventDefault()
    if (this.moved) this.submit()
  }

  end() {
    if (!this.source) return
    if (this.moved) this.submit()
    else this.reset()
  }

  measure() {
    const bounds = this.grid.getBoundingClientRect()

    return Array.from(this.grid.querySelectorAll(".card[data-note-id]")).map(card => {
      const rect = card.getBoundingClientRect()

      return {
        left: rect.left - bounds.left,
        top: rect.top - bounds.top,
        right: rect.right - bounds.left,
        bottom: rect.bottom - bounds.top
      }
    })
  }

  place(event) {
    const bounds = this.grid.getBoundingClientRect()
    const x = event.clientX - bounds.left
    const y = event.clientY - bounds.top
    if (x < 0 || y < 0 || x > bounds.width || y > bounds.height) return

    const cards = Array.from(this.grid.querySelectorAll(".card[data-note-id]"))
    const current = cards.indexOf(this.source)
    const index = Math.min(this.slotAt(x, y), cards.length - 1)
    if (index < 0 || index === current) return

    // Past the card holding the slot when moving forward, before it when moving
    // back, so the card lands on the slot the pointer is over either way.
    this.shuffle(index > current ? cards[index].nextElementSibling : cards[index])
  }

  // Distance to the edge of a slot rather than to its middle: a card's height
  // then decides nothing, and the ragged space a short card leaves below it
  // belongs to that card instead of to no one.
  slotAt(x, y) {
    let nearest = -1
    let shortest = Infinity

    this.slots.forEach((slot, index) => {
      const dx = Math.max(slot.left - x, 0, x - slot.right)
      const dy = Math.max(slot.top - y, 0, y - slot.bottom)
      const distance = dx * dx + dy * dy
      if (distance >= shortest) return

      shortest = distance
      nearest = index
    })

    return nearest
  }

  // Rects are read before the running animations are cancelled, so interrupting
  // a shuffle carries its cards on from where they had got to rather than from a
  // jump back to the grid.
  shuffle(reference) {
    const cards = Array.from(this.grid.querySelectorAll(".card[data-note-id]"))
    const before = new Map(cards.map(card => [card, card.getBoundingClientRect()]))

    this.animations?.forEach(animation => animation.cancel())
    this.grid.insertBefore(this.source, reference)
    this.moved = true
    this.layout(this.grid)

    this.animations = cards.map(card => this.animate(card, before.get(card))).filter(Boolean)
  }

  animate(card, before) {
    const after = card.getBoundingClientRect()
    const dx = before.left - after.left
    const dy = before.top - after.top
    if (Math.abs(dx) < 1 && Math.abs(dy) < 1) return null

    return card.animate(
      [
        { transform: `translate(${dx}px, ${dy}px)` },
        { transform: "translate(0, 0)" }
      ],
      { duration: SHUFFLE_MS, easing: "cubic-bezier(0.2, 0, 0.2, 1)" }
    )
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

  undo(source, original) {
    if (!source || !original?.parent) return

    original.parent.insertBefore(source, original.next)
    this.layout(original.parent)
  }

  layout(grid) {
    const masonry = this.application.getControllerForElementAndIdentifier(grid, "masonry")
    masonry ? masonry.layout() : grid.offsetHeight
  }

  reset() {
    this.source = null
    this.grid = null
    this.original = null
    this.slots = null
    this.moved = false
    this.submitted = false
  }
}
