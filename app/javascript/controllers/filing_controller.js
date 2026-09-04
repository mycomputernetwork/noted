import { Controller } from "@hotwired/stimulus"
import { formHeaders } from "request"

const REJECTION_MS = 2000

// Drag notes into folders or between rows, and drag folders into order.
//
// The dragged element is moved here so the drop lands immediately; the note the
// server returns is then handed to the board, which owns the folder pill, the
// root note's twist and whether the card still belongs here. Only a failed
// write repaints, which is what puts the element back.
export default class extends Controller {
  start(event) {
    const note = event.target.closest("[data-note-id][data-note-url]")
    const folder = event.target.closest(".row--folder[data-folder-url]")

    if (note) {
      this.source = { type: "note", element: note, id: note.dataset.noteId, url: note.dataset.noteUrl }
    } else if (folder) {
      this.source = { type: "folder", element: folder, id: folder.dataset.folderId, url: folder.dataset.folderUrl }
    } else {
      return
    }

    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", this.source.id)
    this.source.element.classList.add("note--dragging")
  }

  end() {
    this.clearIndicators()
    this.source?.element.classList.remove("note--dragging")
    this.source = null
  }

  over(event) {
    const target = this.targetFor(event)
    if (!target) return

    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
    this.markTarget(target, event)
  }

  leave(event) {
    const row = event.currentTarget

    if (!row.contains(event.relatedTarget)) this.clearRow(row)
  }

  track(event) {
    const marked = document.querySelector(".row--drop, .row--insert-before, .row--insert-after")

    if (marked && !marked.contains(event.target)) this.clearRow(marked)
  }

  async drop(event) {
    const target = this.targetFor(event)
    if (!target) return

    event.preventDefault()
    this.clearIndicators()

    const source = this.source
    const isNote = source.type === "note"
    const move = isNote ? this.noteMove(target, event) : this.folderMove(target, event)

    if (isNote) this.moveRailNote(source.id, move)
    else this.moveFolder(source.id, move)

    source.element.classList.add("note--filing")

    try {
      const response = await fetch(source.url, {
        method: "PATCH",
        headers: formHeaders(),
        body: isNote ? this.notePayload(move) : this.folderPayload(move)
      })

      if (!response.ok) throw new Error(`filing failed: ${response.status}`)
      if (isNote && this.board) {
        this.dispatch("filed", { target: this.board, bubbles: false, detail: { note: await response.json() } })
      }
    } catch (error) {
      console.error("[filing]", error)
      this.reject(target.row).then(() => this.dispatch("failed"))
    } finally {
      source.element.classList.remove("note--filing")
    }
  }

  get board() {
    return document.querySelector("[data-controller~='board']")
  }

  noteMove(target, event) {
    if (target.kind === "note") {
      const placement = this.placement(target.row, event)
      return {
        folderId: target.row.dataset.folderId ?? "",
        beforeId: placement === "before" ? target.row.dataset.noteId : null,
        afterId: placement === "after" ? target.row.dataset.noteId : null
      }
    }

    const folderId = target.row.dataset.folderId ?? ""
    return { folderId, beforeId: this.firstRailNote(folderId)?.dataset.noteId ?? null, afterId: null }
  }

  folderMove(target, event) {
    const placement = this.placement(target.row, event)
    return {
      beforeId: placement === "before" ? target.row.dataset.folderId : null,
      afterId: placement === "after" ? target.row.dataset.folderId : null
    }
  }

  moveRailNote(noteId, move) {
    const note = this.railNote(noteId)
    if (!note) return

    const target = move.beforeId ? this.railNote(move.beforeId) : move.afterId ? this.railNote(move.afterId) : null
    const container = target?.parentElement ?? this.railContainer(move.folderId)
    if (!container) return

    if (target && move.afterId) container.insertBefore(note, target.nextSibling)
    else if (target) container.insertBefore(note, target)
    else container.prepend(note)
  }

  // A folder is two siblings — the frame holding its row, and the container
  // holding its notes — and both travel together.
  moveFolder(folderId, move) {
    const frame = this.folderRow(folderId)?.closest("turbo-frame")
    const children = this.railContainer(folderId)
    const parent = frame?.parentNode
    const target = this.folderRow(move.beforeId ?? move.afterId)
    const targetFrame = target?.closest("turbo-frame")
    if (!frame || !children || !parent || !targetFrame) return

    const targetChildren = this.railContainer(target.dataset.folderId)
    const reference = move.beforeId ? targetFrame : targetChildren?.nextSibling ?? targetFrame.nextSibling
    if (reference === frame) return

    parent.insertBefore(frame, reference)
    parent.insertBefore(children, reference)
  }

  targetFor(event) {
    if (!this.source) return null

    const row = event.currentTarget

    if (this.source.type === "note") {
      if (row.matches(".row--note") && row.dataset.noteId !== this.source.id) return { kind: "note", row }
      if (row.matches(".row--folder")) return { kind: "folder", row }
      if (row.matches(".row--view") && row.dataset.folderId !== undefined) return { kind: "root", row }
    }

    if (this.source.type === "folder" && row.matches(".row--folder") && row.dataset.folderId !== this.source.id) {
      return { kind: "folder", row }
    }

    return null
  }

  markTarget(target, event) {
    this.clearIndicators()

    if (target.kind === "root" || (target.kind === "folder" && this.source.type === "note")) {
      target.row.classList.add("row--drop")
      return
    }

    target.row.classList.add(this.placement(target.row, event) === "before" ? "row--insert-before" : "row--insert-after")
  }

  placement(row, event) {
    const bounds = row.getBoundingClientRect()
    return event.clientY < bounds.top + bounds.height / 2 ? "before" : "after"
  }

  clearIndicators() {
    document.querySelectorAll(".row--drop, .row--insert-before, .row--insert-after").forEach(row => this.clearRow(row))
  }

  clearRow(row) {
    row.classList.remove("row--drop", "row--insert-before", "row--insert-after")
  }

  // The repaint that puts the row back waits for the highlight, which the body
  // swap would otherwise take away with the row.
  reject(row) {
    row.classList.add("row--rejected")
    return new Promise(resolve => setTimeout(resolve, REJECTION_MS))
  }

  railNote(noteId) {
    return document.querySelector(`.rail .row--note[data-note-id="${noteId}"]`)
  }

  firstRailNote(folderId) {
    return Array.from(this.railContainer(folderId)?.querySelectorAll(".row--note") ?? [])
      .find(row => row.dataset.noteId !== this.source.id)
  }

  folderRow(folderId) {
    return folderId ? document.querySelector(`.row--folder[data-folder-id="${folderId}"]`) : null
  }

  railContainer(folderId) {
    return document.querySelector(folderId ? `.rail__children[data-folder-id="${folderId}"]` : ".rail__root-notes")
  }

  notePayload(move) {
    const params = new URLSearchParams({ "note[folder_id]": move.folderId })
    if (move.beforeId) params.set("note[before_id]", move.beforeId)
    if (move.afterId) params.set("note[after_id]", move.afterId)
    return params.toString()
  }

  folderPayload(move) {
    const params = new URLSearchParams()
    if (move.beforeId) params.set("folder[before_id]", move.beforeId)
    if (move.afterId) params.set("folder[after_id]", move.afterId)
    return params.toString()
  }
}
