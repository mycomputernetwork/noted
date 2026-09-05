import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]

  connect() {
    this.dropFromSnapshot = () => {
      this.closed()
      this.dialogTarget.close()
    }
    addEventListener("turbo:before-cache", this.dropFromSnapshot)
  }

  disconnect() {
    this.closed()
    removeEventListener("turbo:before-cache", this.dropFromSnapshot)
  }

  open(event) {
    event.preventDefault()
    const noteId = event.currentTarget.closest("[data-note-id]")?.dataset.noteId
    if (noteId) this.openNote(noteId)
  }

  openNote(noteId) {
    if (this.dialogTarget.dataset.noteId) {
      this.pendingNoteId = noteId
      return
    }

    const note = this.board.note(noteId)
    if (!note) return

    this.sourceCard = this.board.card(noteId)
    const origin = this.sourceCard?.getBoundingClientRect()
    const form = this.autosave.formTarget
    const body = form.elements["note[body]"]

    this.dialogTarget.dataset.noteId = note.id
    form.elements["note[title]"].value = note.title || ""
    body.value = note.body || ""
    form.elements["note[folder_id]"].value = note.folder_id || ""
    form.querySelector('input[name="note[pinned]"][type="checkbox"]').checked = note.pinned
    form.querySelector(".editor__expand").href = note.html_url
    this.destination = null

    this.autosave.begin(note)
    this.dialogTarget.showModal()
    this.sourceCard?.classList.add("card--editing")
    this.application.getControllerForElementAndIdentifier(body, "autogrow")?.resize()
    body.focus({ preventScroll: true })
    body.setSelectionRange(body.value.length, body.value.length)
    this.animateOpening(origin)
  }

  animateOpening(origin) {
    this.stopOpening()
    if (!origin?.width || !origin.height || matchMedia("(prefers-reduced-motion: reduce)").matches) return

    const duration = 140
    this.openingAnimation = this.dialogTarget.animate(this.surfaceFrames(origin), {
      duration, easing: "cubic-bezier(0.2, 0, 0, 1)"
    })
    this.contentAnimation = this.dialogTarget.querySelector(".modal__panel").animate(
      [{ opacity: 0 }, { opacity: 1 }],
      { duration: 80, delay: duration, fill: "backwards", easing: "ease-out" }
    )
  }

  surfaceFrames(origin) {
    const destination = this.dialogTarget.getBoundingClientRect()
    return [
      {
        transform: `translate(${origin.left - destination.left}px, ${origin.top - destination.top}px) scale(${origin.width / destination.width}, ${origin.height / destination.height})`,
        transformOrigin: "top left"
      },
      { transform: "none", transformOrigin: "top left" }
    ]
  }

  stopOpening() {
    this.openingAnimation?.cancel()
    this.contentAnimation?.cancel()
    this.openingAnimation = null
    this.contentAnimation = null
  }

  closed() {
    this.stopOpening()
    if (this.hasDialogTarget) {
      this.dialogTarget.classList.remove("modal--closing")
      this.dialogTarget.style.removeProperty("--modal-close-offset")
    }
    this.closing = false
    this.sourceCard?.classList.remove("card--editing")
    this.sourceCard = null
  }

  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }

  cancel(event) {
    event.preventDefault()
    this.close()
  }

  close() {
    if (!this.dialogTarget.open || this.closing) return

    const origin = this.sourceCard?.getBoundingClientRect()
    const time = this.contentAnimation?.currentTime || 0
    if (!this.openingAnimation || !time || !origin?.width || !origin.height ||
        matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.dialogTarget.close()
      return
    }

    this.closing = true
    if (this.openingAnimation.playState === "finished") {
      this.openingAnimation.effect.setKeyframes(this.surfaceFrames(origin))
    }
    this.openingAnimation.currentTime = time
    this.openingAnimation.reverse()
    this.contentAnimation.reverse()
    const offset = this.contentAnimation.effect.getComputedTiming().endTime - time
    this.dialogTarget.style.setProperty("--modal-close-offset", `${offset}ms`)
    this.dialogTarget.classList.add("modal--closing")
    this.openingAnimation.finished.then(() => this.dialogTarget.close(), () => {})
  }

  done(event) {
    if (event.key !== "Enter" || (!event.metaKey && !event.ctrlKey)) return

    event.preventDefault()
    this.close()
  }

  expand(event) {
    event.preventDefault()
    this.destination = event.currentTarget.href
    this.dispatch("expand")
    this.dialogTarget.close()
  }

  finalized() {
    this.dialogTarget.dataset.noteId = ""

    if (this.destination) return Turbo.visit(this.destination)

    if (!this.pendingNoteId) return

    const noteId = this.pendingNoteId
    this.pendingNoteId = null
    this.openNote(noteId)
  }

  get board() {
    return this.application.getControllerForElementAndIdentifier(this.element, "board")
  }

  get autosave() {
    return this.application.getControllerForElementAndIdentifier(this.dialogTarget, "autosave")
  }

}
