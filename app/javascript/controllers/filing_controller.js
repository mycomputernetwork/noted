import { Controller } from "@hotwired/stimulus"

// Drag a note onto a folder to file it. Mounted on the shell so one controller
// sees the board and sidebar sources and the sidebar targets.
export default class extends Controller {
  start(event) {
    const source = event.target.closest("[data-note-id][data-note-url]")
    if (!source) return

    this.source = source
    this.url = source.dataset.noteUrl

    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", source.dataset.noteId)

    source.classList.add("note--dragging")
  }

  end() {
    this.source?.classList.remove("note--dragging")
    this.source = null
    this.url = null
  }

  over(event) {
    if (!this.source) return

    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
    event.currentTarget.classList.add("row--drop")
  }

  leave(event) {
    const row = event.currentTarget

    if (!row.contains(event.relatedTarget)) row.classList.remove("row--drop")
  }

  async drop(event) {
    if (!this.source) return
    event.preventDefault()

    const row = event.currentTarget
    const source = this.source
    const url = this.url
    const folderId = row.dataset.folderId ?? ""

    row.classList.remove("row--drop")
    source.classList.add("note--filing")

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
      source.classList.remove("note--filing")
      row.classList.add("row--rejected")
      setTimeout(() => row.classList.remove("row--rejected"), 1200)

      console.error("[filing]", error)
    }
  }

  get csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content
  }
}
