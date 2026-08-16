import { Controller } from "@hotwired/stimulus"

// A textarea the height of its own content. Reset to auto before measuring,
// because scrollHeight never shrinks below the height already set.
export default class extends Controller {
  connect() {
    this.resize()
    document.fonts?.ready.then(() => this.resize())
  }

  resize() {
    this.element.style.height = "auto"
    this.element.style.height = `${this.element.scrollHeight}px`
  }
}
