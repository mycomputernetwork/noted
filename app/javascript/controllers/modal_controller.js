import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]

  connect() {
    this.dropFromSnapshot = () => this.dialogTarget.close()
    addEventListener("turbo:before-cache", this.dropFromSnapshot)
  }

  disconnect() {
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
    this.application.getControllerForElementAndIdentifier(body, "autogrow")?.resize()
    body.focus()
    body.setSelectionRange(body.value.length, body.value.length)
  }

  backdrop(event) {
    if (event.target === this.dialogTarget) this.dialogTarget.close()
  }

  close() {
    this.dialogTarget.close()
  }

  done(event) {
    if (event.key !== "Enter" || (!event.metaKey && !event.ctrlKey)) return

    event.preventDefault()
    this.dialogTarget.close()
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
