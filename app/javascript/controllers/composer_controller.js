import { Controller } from "@hotwired/stimulus"

// The composer: the frame around a new note. Opens, decides what "done" means,
// and hands off to autosave.
export default class extends Controller {
  connect() {
    this.outsideClick = (event) => {
      if (!this.element.contains(event.target)) this.close()
    }
    this.escape = (event) => {
      if (event.key === "Escape") this.close()
    }

    // Deferred a frame: the click that opened the composer is still travelling
    // and would otherwise close it immediately.
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

  remember({ detail: { note } }) {
    this.noteId = note.id
  }

  forget() {
    this.noteId = null
  }

  teardown() {
    if (this.noteId) {
      this.selectCard(this.noteId)
    } else {
      this.frame.src = window.location.href
    }
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

  get frame() {
    return this.element.closest("turbo-frame")
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
