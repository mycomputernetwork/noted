import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "form", "field"]

  open() {
    this.buttonTarget.hidden = true
    this.formTarget.hidden = false
    this.fieldTarget.focus()
  }

  close() {
    this.fieldTarget.value = ""
    this.formTarget.hidden = true
    this.buttonTarget.hidden = false
  }

  // Escape always closes; a blur only does when nothing has been typed, so
  // clicking elsewhere in the window does not throw away a half-typed name.
  cancel(event) {
    if (event.type !== "keydown") {
      if (!this.fieldTarget.value.trim()) this.close()
      return
    }

    if (event.key !== "Escape") return
    this.close()
    this.buttonTarget.focus()
  }

  submit(event) {
    if (this.fieldTarget.value.trim()) return

    event.preventDefault()
    this.close()
  }
}
