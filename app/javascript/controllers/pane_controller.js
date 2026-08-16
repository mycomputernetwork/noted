import { Controller } from "@hotwired/stimulus"

// The full pane's frame. A pane is just a page — autosave already flushes on
// turbo:before-visit and unload — so the only thing left is that Enter in a
// text input still submits the form.
export default class extends Controller {
  preventSubmit(event) {
    event.preventDefault()
  }
}
