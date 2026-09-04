import { Controller } from "@hotwired/stimulus"

// Masonry as a CSS grid of 1px rows, each card spanning its measured height.
// Measurement is read-all-then-write-all in one frame to avoid a synchronous
// layout per card.
export default class extends Controller {
  static targets = ["item"]

  connect() {
    this.scheduleLayout = this.scheduleLayout.bind(this)
    this.keepMeasurement = this.keepMeasurement.bind(this)

    // Neither the measured class nor a card's span is in the server's HTML, so a
    // morph would drop the board to unmeasured for the frame before the next
    // measurement lands.
    this.element.addEventListener("turbo:before-morph-attribute", this.keepMeasurement)

    // Per-item as well as container: a card grows after its images decode.
    this.resizeObserver = new ResizeObserver(this.scheduleLayout)
    this.resizeObserver.observe(this.element)
    this.itemTargets.forEach((item) => this.resizeObserver.observe(item))

    document.fonts?.ready.then(this.scheduleLayout)

    this.scheduleLayout()
  }

  disconnect() {
    this.element.removeEventListener("turbo:before-morph-attribute", this.keepMeasurement)
    this.resizeObserver?.disconnect()
    if (this.frame) cancelAnimationFrame(this.frame)
    this.element.classList.remove("masonry--measured")
  }

  keepMeasurement(event) {
    const attribute = event.target === this.element ? "class" : "style"
    if (event.detail.attributeName === attribute) event.preventDefault()
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

    const heights = items.map((item) => item.getBoundingClientRect().height)

    const gap = parseFloat(getComputedStyle(this.element).columnGap) || 0

    this.element.classList.add("masonry--measured")

    items.forEach((item, index) => {
      item.style.gridRowEnd = `span ${Math.ceil(heights[index]) + gap}`
    })
  }
}
