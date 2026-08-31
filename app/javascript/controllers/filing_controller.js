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
    const noteId = source.dataset.noteId
    const url = this.url
    const folderId = row.dataset.folderId ?? ""
    const change = this.moveNote(noteId, folderId, row)

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
    } catch (error) {
      change.undo()
      row.classList.add("row--rejected")
      setTimeout(() => row.classList.remove("row--rejected"), 1200)

      console.error("[filing]", error)
    } finally {
      source.classList.remove("note--filing")
    }
  }

  moveNote(noteId, folderId, row) {
    const railNote = this.railNote(noteId)
    const card = this.card(noteId)
    const state = {
      rail: this.stateOf(railNote),
      card: this.stateOf(card),
      cardFolder: card?.dataset.folderId,
      cardFolderPill: card?.querySelector(".card__folder")?.textContent
    }

    this.moveRailNote(railNote, folderId)
    this.updateCard(card, folderId, row)

    return { undo: () => this.undoMove(state) }
  }

  moveRailNote(note, folderId) {
    if (!note) return

    const oldContainer = note.parentElement
    const target = this.railContainer(folderId)
    if (!target || target === oldContainer) return

    this.setRootNote(note, folderId === "")
    target.append(note)
    this.syncEmptyFolder(oldContainer)
    this.syncEmptyFolder(target)
  }

  updateCard(card, folderId, row) {
    if (!card) return

    const boardFolderId = document.querySelector(".board")?.dataset.folderId
    card.dataset.folderId = folderId

    if (boardFolderId && boardFolderId !== folderId) {
      card.remove()
      return
    }

    this.updateFolderPill(card, folderId, row)
  }

  undoMove(state) {
    this.restore(state.rail)
    this.restore(state.card)

    if (state.card?.element) {
      state.card.element.dataset.folderId = state.cardFolder ?? ""
      this.updateFolderPill(state.card.element, state.cardFolder ?? "", null, state.cardFolderPill)
    }

    document.querySelectorAll(".rail__children").forEach(container => this.syncEmptyFolder(container))
  }

  restore(state) {
    if (!state?.element || !state.parent) return

    state.parent.insertBefore(state.element, state.next)
    this.setRootNote(state.element, state.root)
  }

  updateFolderPill(card, folderId, row, label) {
    let pill = card.querySelector(".card__folder")

    if (!folderId) {
      pill?.remove()
      return
    }

    if (!pill) {
      pill = document.createElement("span")
      pill.className = "card__folder"
      card.querySelector(".card__meta")?.prepend(pill)
    }

    pill.textContent = label ?? row?.querySelector(".row__label")?.textContent?.trim() ?? ""
  }

  setRootNote(note, root) {
    note.classList.toggle("row--root", root)

    const twist = note.querySelector(":scope > .row__twist")
    if (root && !twist) note.prepend(this.rootTwist())
    if (!root && twist) twist.remove()
  }

  rootTwist() {
    const twist = document.createElement("span")
    twist.className = "row__twist"
    twist.setAttribute("aria-hidden", "true")
    return twist
  }

  syncEmptyFolder(container) {
    if (!container?.classList.contains("rail__children")) return

    const empty = container.querySelector(".rail__empty")
    if (container.querySelector(".row--note")) {
      empty?.remove()
      return
    }

    if (empty) return

    const placeholder = document.createElement("p")
    placeholder.className = "rail__empty"
    placeholder.textContent = "empty"
    container.append(placeholder)
  }

  stateOf(element) {
    if (!element) return null

    return { element, parent: element.parentNode, next: element.nextSibling, root: element.classList.contains("row--root") }
  }

  railNote(noteId) {
    return document.querySelector(`.rail .row--note[data-note-id="${noteId}"]`)
  }

  card(noteId) {
    return document.querySelector(`.board .card[data-note-id="${noteId}"]`)
  }

  railContainer(folderId) {
    return document.querySelector(folderId ? `.rail__children[data-folder-id="${folderId}"]` : ".rail__root-notes")
  }

  get csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content
  }
}
