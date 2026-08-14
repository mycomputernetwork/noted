import { Controller } from "@hotwired/stimulus"

// Drag a card onto a folder to file it (PRD §11).
//
// Mounted on the shell, because the two ends of this interaction are in
// different halves of it: the card is in the main pane and the folder row is
// in the sidebar. `dragstart` bubbles, so one controller on the shell sees
// every card without a controller per card.
//
// Native HTML5 drag events, no library (§11). Filing goes through the note's
// own endpoint — it is an update to a note, not a folder operation — so this
// adds no route and reuses the JSON the autosave controller already talks to.
export default class extends Controller {
  // --- The card end -------------------------------------------------------

  start(event) {
    const card = event.target.closest(".card")
    if (!card) return

    this.card = card
    this.url = card.dataset.noteUrl

    // The card wraps a full-cover link and a dragged link drags its href, so
    // the payload is overwritten with the note's id rather than left as a URL
    // some other application might accept.
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", card.dataset.noteId)

    card.classList.add("card--dragging")
  }

  end() {
    this.card?.classList.remove("card--dragging")
    this.card = null
  }

  // --- The folder end -----------------------------------------------------

  // Filing and reordering are different outcomes and must not look the same
  // mid-drag (§11), so this is a filled highlight. Milestone 13's insertion
  // line is the other one.
  over(event) {
    if (!this.card) return

    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
    event.currentTarget.classList.add("row--drop")
  }

  leave(event) {
    event.currentTarget.classList.remove("row--drop")
  }

  // Immediate and optimistic, with rollback on failure (§11). The card dims
  // the moment it lands rather than when the server agrees, and the board is
  // only re-rendered once it has: filing moves a note between boards, and
  // rendering that twice would show it in two places.
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
      // Nothing moved. Put the card back and say so on the row that refused
      // it, which is where the eye already is.
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
