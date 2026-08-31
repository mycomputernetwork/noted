import { Controller } from "@hotwired/stimulus"

// The editor's frame: a native <dialog>. Opens it, treats every close the same,
// and refreshes the board once autosave says nothing is in flight.
export default class extends Controller {
  connect() {
    if (!this.element.open) this.element.showModal()

    // showModal focuses the first focusable element (the pin toggle); a card
    // was clicked to get here, so put the caret at the end of the body instead.
    const body = this.element.querySelector(".editor__body")
    if (!body) return

    body.focus()
    body.setSelectionRange(body.value.length, body.value.length)
  }

  // The dialog is only the event target when the click landed on the backdrop.
  backdrop(event) {
    if (event.target === this.element) this.element.close()
  }

  close() {
    this.element.close()
  }

  // No submit button, but Enter in a text input still submits the form.
  preventSubmit(event) {
    event.preventDefault()
  }

  teardown() {
    this.element.remove()
  }

  get frame() {
    return this.element.closest("turbo-frame")
  }
}
