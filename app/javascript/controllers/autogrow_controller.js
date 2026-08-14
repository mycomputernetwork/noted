import { Controller } from "@hotwired/stimulus"

// A textarea the height of its own content.
//
// The body field has no scrollbar and no drag handle: a note is as tall as
// it is, and the surface around it scrolls. Height is reset to `auto` before
// each measurement because scrollHeight never shrinks below the height
// already set.
export default class extends Controller {
  connect() {
    this.resize()
    // The real font changes the metrics after first paint.
    document.fonts?.ready.then(() => this.resize())
  }

  resize() {
    this.element.style.height = "auto"
    this.element.style.height = `${this.element.scrollHeight}px`
  }
}
