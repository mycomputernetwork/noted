import { Controller } from "@hotwired/stimulus"

// The editor's frame (PRD §8.2).
//
// A native <dialog>, so the backdrop, Escape and the focus trap come from the
// platform rather than from a library (PRD §13). This controller is only the
// frame: it opens the dialog, treats every way of closing as the same way,
// and refreshes the board once the autosave controller says nothing is still
// in flight. It knows nothing about notes, fields or saving — milestone 4's
// full-pane note drops this file and keeps the autosave controller.
export default class extends Controller {
  connect() {
    if (!this.element.open) this.element.showModal()

    // showModal focuses the first focusable thing in the dialog, which is the
    // pin toggle in the corner. A card was clicked to get here, so the caret
    // belongs at the end of the text instead.
    const body = this.element.querySelector(".editor__body")
    if (!body) return

    body.focus()
    body.setSelectionRange(body.value.length, body.value.length)
  }

  // Backdrop click. The dialog itself is only ever the target when the click
  // landed outside the panel, since the panel covers the dialog's own box.
  backdrop(event) {
    if (event.target === this.element) this.element.close()
  }

  close() {
    this.element.close()
  }

  // There is no submit button, but Enter in a text input still asks the form
  // to submit. Saving is implicit; submitting is not a thing that happens.
  preventSubmit(event) {
    event.preventDefault()
  }

  // Fired by autosave:finalized, which means the last save has landed and an
  // emptied note has already been discarded. Only then is it safe to reload
  // the board — refreshing before the save returns would render the note as
  // it was before the edit.
  //
  // A visit to the current URL is a Turbo page refresh, and the layout asks
  // for morphing, so the board is patched rather than rebuilt: scroll
  // position holds and only the cards that actually changed move. The edited
  // note moving to the front under "last edited" sorting is the point — a
  // card updated in place would leave the board sorted wrongly.
  teardown() {
    this.frame?.remove()
    window.Turbo.visit(window.location.href, { action: "replace" })
  }

  get frame() {
    return this.element.closest("turbo-frame")
  }
}
