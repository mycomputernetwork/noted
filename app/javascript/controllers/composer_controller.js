import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.outsideClick = (event) => {
      if (!this.element.contains(event.target)) this.close()
    }
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

  remember({ detail: { note } }) {
    this.noteId = note.id
  }

  forget() {
    this.noteId = null
  }

  teardown() {
    if (!this.noteId || select(this.noteId)) return

    // The repaint that puts the card on the board has not landed yet, and this
    // element is gone by the time it does, so the retry is parked on the window.
    // The extra frame lets masonry place the card before it is scrolled to.
    const id = this.noteId
    addEventListener("turbo:render", () => requestAnimationFrame(() => select(id)), { once: true })
  }

  get body() {
    return this.element.querySelector(".editor__body")
  }
}

function select(id) {
  const card = document.getElementById(`note_${id}`)
  if (!card) return false

  card.classList.add("card--selected")
  card.querySelector(".card__open")?.focus({ preventScroll: true })
  card.scrollIntoView({ block: "nearest", behavior: "smooth" })
  return true
}
