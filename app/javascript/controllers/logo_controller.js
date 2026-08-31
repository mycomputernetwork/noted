import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["animated"]

  connect() {
    setTimeout(() => {
      this.animatedTarget.src = this.animatedTarget.dataset.staticSrc
    }, 1000)
  }
}
