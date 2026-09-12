import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]

  position() {
    if (!this.element.open) return

    this.element.classList.remove("card__menu--flipped")
    const overflows = this.panelTarget.getBoundingClientRect().right > document.documentElement.clientWidth
    this.element.classList.toggle("card__menu--flipped", overflows)
  }
}
