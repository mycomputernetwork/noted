import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "title", "body", "folder", "pinned", "expand"]

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
    if (this.isClosing) {
      this.pendingNoteId = noteId
      return
    }

    const note = this.board.note(noteId)
    if (!note) return

    this.dialogTarget.dataset.noteId = note.id
    this.titleTarget.value = note.title || ""
    this.bodyTarget.value = note.body || ""
    this.folderTarget.value = note.folder_id || ""
    this.pinnedTarget.checked = note.pinned
    this.expandTarget.href = note.html_url
    this.destination = null

    this.autosave.begin(note)
    this.dialogTarget.showModal()
    this.autogrow?.resize()
    this.bodyTarget.focus()
    this.bodyTarget.setSelectionRange(this.bodyTarget.value.length, this.bodyTarget.value.length)
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

  beginClose() {
    this.isClosing = true
  }

  finalized() {
    this.dialogTarget.dataset.noteId = ""

    if (this.destination) return Turbo.visit(this.destination)

    this.isClosing = false
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

  get autogrow() {
    return this.application.getControllerForElementAndIdentifier(this.bodyTarget, "autogrow")
  }
}
