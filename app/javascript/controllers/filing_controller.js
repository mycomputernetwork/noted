import { Controller } from "@hotwired/stimulus"

// Drag a card onto a folder to file it. Mounted on the shell so one controller
// sees every card (dragstart bubbles); filing is a PATCH to the note, no route.
export default class extends Controller {
  // --- The card end -------------------------------------------------------

  start(event) {
    const card = event.target.closest(".card")
    if (!card) return

    this.card = card
    this.url = card.dataset.noteUrl

    // The card wraps a full-cover link, and a dragged link drags its href, so
    // overwrite the payload with the note id.
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", card.dataset.noteId)

    card.classList.add("card--dragging")
  }

  end() {
    this.card?.classList.remove("card--dragging")
    this.card = null
  }

  // --- The folder end -----------------------------------------------------

  // Bound to dragenter as well as dragover: Firefox won't fire drop unless the
  // drag is accepted on entry, not only while moving over the target.
  over(event) {
    if (!this.card) return

    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
    event.currentTarget.classList.add("row--drop")
  }

  // dragleave fires when the pointer crosses into a child of the row, so only
  // a leave that lands outside the row counts.
  leave(event) {
    const row = event.currentTarget

    if (!row.contains(event.relatedTarget)) row.classList.remove("row--drop")
  }

  // Optimistic, with rollback on failure; the board re-renders only after the
  // server agrees, since filing moves a note between boards.
  async drop(event) {
    if (!this.card) return
    event.preventDefault()

    const row = event.currentTarget
    const card = this.card
    const url = this.url
    const folderId = row.dataset.folderId ?? ""

    row.classList.remove("row--drop")
    card.classList.add("card--filing")

    try {
      const response = await fetch(url, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "Accept": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: new URLSearchParams({ "note[folder_id]": folderId }).toString()
      })

      if (!response.ok) throw new Error(`filing failed: ${response.status}`)

      window.Turbo.visit(window.location.href, { action: "replace" })
    } catch (error) {
      card.classList.remove("card--filing")
      row.classList.add("row--rejected")
      setTimeout(() => row.classList.remove("row--rejected"), 1200)

      console.error("[filing]", error)
    }
  }

  get csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content
  }
}
