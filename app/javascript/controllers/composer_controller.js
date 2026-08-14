import { Controller } from "@hotwired/stimulus"

// The composer, expanded in place at the top of the board (PRD §8.2).
//
// The frame around a new note, in the same sense that modal_controller is the
// frame around an existing one: it opens, it decides what counts as "done",
// and it hands off to the autosave controller, which it knows nothing about
// beyond the two events it listens for.
//
// A dialog would be wrong here. There is nothing behind a new note to keep
// visible, and a scrim over the board while writing one would put the note
// somewhere other than where it is about to live.
//
// Done is: a click outside, Escape, or the Done button. All three are the
// same act and all three save, exactly as the modal's three ways of closing
// are (§8.2).
export default class extends Controller {
  connect() {
    this.outsideClick = (event) => {
      if (!this.element.contains(event.target)) this.close()
    }
    this.escape = (event) => {
      if (event.key === "Escape") this.close()
    }

    // Deferred by a frame: the click that opened the composer is still
    // travelling, and would otherwise close it again immediately.
    requestAnimationFrame(() => document.addEventListener("mousedown", this.outsideClick))
    document.addEventListener("keydown", this.escape)

    this.body?.focus()
  }

  disconnect() {
    document.removeEventListener("mousedown", this.outsideClick)
    document.removeEventListener("keydown", this.escape)
  }

  close() {
    if (this.closing) return
    this.closing = true
    this.dispatch("done")
  }

  preventSubmit(event) {
    event.preventDefault()
  }

  // The id only exists once something has actually been typed and saved.
  remember({ detail: { note } }) {
    this.noteId = note.id
  }

  // Typed into and emptied out again: the record has just been discarded, so
  // there is no card to go and select.
  forget() {
    this.noteId = null
  }

  // Fired by autosave:finalized — the last save has landed and an emptied
  // note has already been discarded.
  teardown() {
    if (this.noteId) {
      // The note exists now, so the board has to be re-sorted around it: the
      // card belongs wherever "last edited" puts it, which is the front.
      // Marking it on arrival is the point of the whole exchange — a note
      // that drops into a masonry grid and is not pointed at is a note you
      // have to go and find.
      selectCardOnNextRender(this.noteId)
      window.Turbo.visit(window.location.href, { action: "replace" })
    } else {
      // Nothing was written. Collapse the composer on its own rather than
      // refreshing a board that cannot have changed.
      this.frame.src = window.location.href
    }
  }

  get frame() {
    return this.element.closest("turbo-frame")
  }

  get body() {
    return this.element.querySelector(".editor__body")
  }
}

// Selection outlives the controller: the element that asked for it is gone by
// the time the board has re-rendered, so the request is parked on the window
// and collected by the next render.
function selectCardOnNextRender(id) {
  const select = () => {
    const card = document.getElementById(`note_${id}`)
    if (!card) return

    card.classList.add("card--selected")
    card.querySelector(".card__open")?.focus({ preventScroll: true })
    card.scrollIntoView({ block: "nearest", behavior: "smooth" })
  }

  // turbo:render covers both a morphed refresh and a full replacement; the
  // frame after it lets the masonry controller place the card first, so the
  // scroll goes to where it ends up rather than where it landed.
  addEventListener("turbo:render", () => requestAnimationFrame(select), { once: true })
}
