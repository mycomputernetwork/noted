import { Controller } from "@hotwired/stimulus"

// The composer: the frame around a new note. Opens, decides what "done" means,
// and hands off to autosave.
export default class extends Controller {
  connect() {
    this.outsideClick = (event) => {
      if (!this.element.contains(event.target)) this.close()
    }
    // Escape and Cmd/Ctrl+Enter mean what clicking away means: done, saved, on
    // the board.
    this.keys = (event) => {
      if (event.key === "Escape" || (event.key === "Enter" && (event.metaKey || event.ctrlKey))) this.close()
    }

    // Deferred a frame: the click that opened the composer is still travelling
    // and would otherwise close it immediately.
    requestAnimationFrame(() => document.addEventListener("mousedown", this.outsideClick))
    document.addEventListener("keydown", this.keys)

    this.body?.focus()
  }

  disconnect() {
    document.removeEventListener("mousedown", this.outsideClick)
    document.removeEventListener("keydown", this.keys)
  }

  close() {
    if (this.closing) return
    this.closing = true
    this.dispatch("done")
  }

  preventSubmit(event) {
    event.preventDefault()
  }

  remember({ detail: { note } }) {
    this.noteId = note.id
  }

  forget() {
    this.noteId = null
  }

  // The board repaints on autosave:finalized, which closes this frame with it;
  // all that is left is to point at the card that was just written.
  teardown() {
    if (this.noteId) this.selectCard(this.noteId)
  }

  selectCard(id) {
    const card = document.getElementById(`note_${id}`)
    if (card) {
      card.classList.add("card--selected")
      card.querySelector(".card__open")?.focus({ preventScroll: true })
      card.scrollIntoView({ block: "nearest", behavior: "smooth" })
    } else {
      selectCardOnNextRender(id)
    }
  }

  get body() {
    return this.element.querySelector(".editor__body")
  }
}

// Parked on the window because the element that asked for it is gone by the
// time the board re-renders. The extra frame lets masonry place the card first,
// so the scroll targets where it ends up.
function selectCardOnNextRender(id) {
  const select = () => {
    const card = document.getElementById(`note_${id}`)
    if (!card) return

    card.classList.add("card--selected")
    card.querySelector(".card__open")?.focus({ preventScroll: true })
    card.scrollIntoView({ block: "nearest", behavior: "smooth" })
  }

  addEventListener("turbo:render", () => requestAnimationFrame(select), { once: true })
}
