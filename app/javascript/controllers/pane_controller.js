import { Controller } from "@hotwired/stimulus"

// The full pane's frame (PRD §7.7), in the same sense that modal_controller
// and composer_controller are frames: it owns the surface and knows nothing
// about saving.
//
// It is this small because the pane is the surface that needs the least. A
// modal has to open, trap focus and decide what closing means; the composer
// has to decide what "done" is and where the new note went. A pane is just a
// page — you arrive by navigating and you leave by navigating, and autosave
// already flushes on `turbo:before-visit` and on unload.
//
// What is left is the one thing a page cannot do on its own: there is no
// submit button anywhere in this application (§8.1), but Enter in a text
// input still asks the form to submit.
export default class extends Controller {
  preventSubmit(event) {
    event.preventDefault()
  }
}
