import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.outsideClick = (event) => {
      if (!this.element.contains(event.target)) this.close()
    }
    this.keys = (event) => {
      if (event.key !== "Escape" && (event.key !== "Enter" || (!event.metaKey && !event.ctrlKey))) return

      event.preventDefault()
      this.close()
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
    const frame = this.element.closest("turbo-frame")
    const link = document.createElement("a")
    link.href = this.element.dataset.newUrl
    link.className = "composer"

    const field = document.createElement("span")
    field.className = "composer__field"
    field.textContent = "Take a note…"
    link.append(field)
    frame.replaceChildren(link)

    if (this.noteId) requestAnimationFrame(() => select(this.noteId))
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
