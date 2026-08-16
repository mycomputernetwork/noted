import { Controller } from "@hotwired/stimulus"

// Masonry as a CSS grid of 1px rows, each card spanning its measured height.
// Not CSS `columns`: those fill column one top-to-bottom, so with "last edited"
// sorting the newest note lands mid-screen and visual order stops matching sort
// order. Measurement is read-all-then-write-all in one frame to avoid a
// synchronous layout per card.
export default class extends Controller {
  static targets = ["item"]
  static values = { gap: { type: Number, default: 16 } }

  connect() {
    this.scheduleLayout = this.scheduleLayout.bind(this)

    // Container observer catches viewport/column changes; per-item observers
    // catch a card growing after its images decode.
    this.resizeObserver = new ResizeObserver(this.scheduleLayout)
    this.resizeObserver.observe(this.element)
    this.itemTargets.forEach((item) => this.resizeObserver.observe(item))

    // Metrics change once the real font is in use.
    document.fonts?.ready.then(this.scheduleLayout)

    this.scheduleLayout()
  }

  disconnect() {
    this.resizeObserver?.disconnect()
    if (this.frame) cancelAnimationFrame(this.frame)
    this.element.classList.remove("masonry--measured")
  }

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

    // Gap from the computed column gap, so packing can't drift from the stylesheet.
    const gap = parseFloat(getComputedStyle(this.element).columnGap) || this.gapValue

    this.element.classList.add("masonry--measured")

    items.forEach((item, index) => {
      // Rows are 1px with no row gap, so span = height + the following gap.
      const span = Math.ceil(heights[index]) + gap
      item.style.gridRowEnd = `span ${span}`
    })
  }
}
