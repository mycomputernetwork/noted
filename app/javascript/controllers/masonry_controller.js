import { Controller } from "@hotwired/stimulus"

// Masonry with correct reading order.
//
// The board is a CSS grid with 1px rows. Each card is given a row span equal
// to its own measured height, so cards pack upward into whatever vertical
// space is free while still being placed by the grid in source order —
// left-to-right, top-to-bottom (PRD §7.1).
//
// CSS `columns` would do the packing for free and is rejected for exactly
// that reason: it fills column one top to bottom before starting column two,
// so with "last edited" sorting the newest note lands halfway down the screen
// and the visual order stops matching the sort order.
//
// Measurement is read-then-write in one animation frame: every card's height
// is read first, then every span written. Interleaving the two would force a
// synchronous layout per card, which is what makes naive masonry janky on a
// board of a few hundred notes.
export default class extends Controller {
  static targets = ["item"]
  static values = { gap: { type: Number, default: 16 } }

  connect() {
    this.scheduleLayout = this.scheduleLayout.bind(this)

    // One observer for the container handles viewport and column-count
    // changes; a per-item observer catches a card growing after its images
    // decode without polling.
    this.resizeObserver = new ResizeObserver(this.scheduleLayout)
    this.resizeObserver.observe(this.element)
    this.itemTargets.forEach((item) => this.resizeObserver.observe(item))

    // Metrics change again once the real font is in use.
    document.fonts?.ready.then(this.scheduleLayout)

    this.scheduleLayout()
  }

  disconnect() {
    this.resizeObserver?.disconnect()
    if (this.frame) cancelAnimationFrame(this.frame)
    this.element.classList.remove("masonry--measured")
  }

  // A card added or removed by Turbo re-runs the layout without a reconnect.
  itemTargetConnected(item) {
    this.resizeObserver?.observe(item)
    this.scheduleLayout()
  }

  itemTargetDisconnected(item) {
    this.resizeObserver?.unobserve(item)
    this.scheduleLayout()
  }

  scheduleLayout() {
    if (this.frame) cancelAnimationFrame(this.frame)
    this.frame = requestAnimationFrame(() => {
      this.frame = null
      this.layout()
    })
  }

  layout() {
    const items = this.itemTargets
    if (items.length === 0) return

    // Read every height before writing any span.
    const heights = items.map((item) => item.getBoundingClientRect().height)

    // The gap comes from the --board-gap token via the computed column gap,
    // so the packing cannot drift out of step with the stylesheet.
    const gap = parseFloat(getComputedStyle(this.element).columnGap) || this.gapValue

    this.element.classList.add("masonry--measured")

    items.forEach((item, index) => {
      // Rows are 1px with no row gap, so the span is the card's height plus
      // the gap that follows it. The trailing gap on the last row is absorbed
      // by the board's bottom padding.
      const span = Math.ceil(heights[index]) + gap
      item.style.gridRowEnd = `span ${span}`
    })
  }
}
