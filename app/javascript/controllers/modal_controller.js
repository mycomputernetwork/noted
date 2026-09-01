import { Controller } from "@hotwired/stimulus"

// The editor's frame: a native <dialog>. Opens it, treats every close the same,
// and refreshes the board once autosave says nothing is in flight.
export default class extends Controller {
  connect() {
    if (!this.element.open) this.element.showModal()

    // A cached dialog comes back with its `open` attribute and none of the
    // top-layer state showModal gave it, so it restores as a block at the foot
    // of the board. The snapshot is better off without it.
    this.dropFromSnapshot = () => this.element.remove()
    addEventListener("turbo:before-cache", this.dropFromSnapshot)

    // showModal focuses the first focusable element (the pin toggle); a card
    // was clicked to get here, so put the caret at the end of the body instead.
    const body = this.element.querySelector(".editor__body")
    if (!body) return

    body.focus()
    body.setSelectionRange(body.value.length, body.value.length)
  }

  disconnect() {
    removeEventListener("turbo:before-cache", this.dropFromSnapshot)
  }

  // The dialog is only the event target when the click landed on the backdrop.
  backdrop(event) {
    if (event.target === this.element) this.element.close()
  }

  close() {
    this.element.close()
  }

  // The full pane renders the note as the server has it, so the visit waits for
  // the last save to land. The dialog stays open while it does: closing it first
  // shows the board for as long as the request takes.
  expand(event) {
    event.preventDefault()
    this.destination = event.currentTarget.href
    this.dispatch("expand")
  }

  // No submit button, but Enter in a text input still submits the form.
  preventSubmit(event) {
    event.preventDefault()
  }

  // Turbo discards the dialog along with the rest of the page it is leaving.
  teardown() {
    if (this.destination) return Turbo.visit(this.destination)

    this.element.remove()
  }

  get frame() {
    return this.element.closest("turbo-frame")
  }
}
