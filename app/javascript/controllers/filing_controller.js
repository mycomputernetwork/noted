import { Controller } from "@hotwired/stimulus"

// Drag notes into folders or between rows, and drag folders into order.
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

  async drop(event) {
    const target = this.targetFor(event)
    if (!target) return

    event.preventDefault()
    this.clearIndicators()

    if (this.source.type === "note") {
      await this.dropNote(target, event)
    } else {
      await this.dropFolder(target, event)
    }
  }

  async dropNote(target, event) {
    const source = this.source
    const move = this.noteMove(target, event)
    const change = this.moveNote(source.id, move)

    source.element.classList.add("note--filing")

    try {
      const response = await fetch(source.url, {
        method: "PATCH",
        headers: this.headers,
        body: this.notePayload(move)
      })

      if (!response.ok) throw new Error(`filing failed: ${response.status}`)
    } catch (error) {
      change.undo()
      this.reject(target.row)
      console.error("[filing]", error)
    } finally {
      source.element.classList.remove("note--filing")
    }
  }

  async dropFolder(target, event) {
    const source = this.source
    const move = this.folderMove(target, event)
    const change = this.moveFolder(source.id, move)

    source.element.classList.add("note--filing")

    try {
      const response = await fetch(source.url, {
        method: "PATCH",
        headers: this.headers,
        body: this.folderPayload(move)
      })

      if (!response.ok) throw new Error(`folder move failed: ${response.status}`)
    } catch (error) {
      change.undo()
      this.reject(target.row)
      console.error("[filing]", error)
    } finally {
      source.element.classList.remove("note--filing")
    }
  }

  noteMove(target, event) {
    if (target.kind === "note") {
      const placement = this.placement(target.row, event)
      return {
        folderId: target.row.dataset.folderId ?? "",
        beforeId: placement === "before" ? target.row.dataset.noteId : null,
        afterId: placement === "after" ? target.row.dataset.noteId : null,
        row: target.row
      }
    }

    const folderId = target.row.dataset.folderId ?? ""
    const first = this.firstRailNote(folderId)
    return { folderId, beforeId: first?.dataset.noteId ?? null, afterId: null, row: target.row }
  }

  folderMove(target, event) {
    const placement = this.placement(target.row, event)
    return {
      beforeId: placement === "before" ? target.row.dataset.folderId : null,
      afterId: placement === "after" ? target.row.dataset.folderId : null,
      row: target.row
    }
  }

  moveNote(noteId, move) {
    const railNote = this.railNote(noteId)
    const card = this.card(noteId)
    const state = {
      rail: this.stateOf(railNote),
      card: this.stateOf(card),
      cardFolder: card?.dataset.folderId,
      cardFolderPill: card?.querySelector(".card__folder")?.textContent
    }

    this.moveRailNote(railNote, move)
    this.updateCard(card, move.folderId, this.folderRow(move.folderId))

    return { undo: () => this.undoNoteMove(state) }
  }

  moveRailNote(note, move) {
    if (!note) return

    const oldContainer = note.parentElement
    const target = move.beforeId ? this.railNote(move.beforeId) : move.afterId ? this.railNote(move.afterId) : null
    const container = target?.parentElement ?? this.railContainer(move.folderId)
    if (!container) return

    note.dataset.folderId = move.folderId
    this.setRootNote(note, move.folderId === "")

    if (target && move.afterId) {
      container.insertBefore(note, target.nextSibling)
    } else if (target) {
      container.insertBefore(note, target)
    } else {
      container.prepend(note)
    }

    this.syncEmptyFolder(oldContainer)
    this.syncEmptyFolder(container)
  }

  moveFolder(folderId, move) {
    const state = this.folderState(folderId)
    const target = this.folderRow(move.beforeId ?? move.afterId)
    const targetFrame = target?.closest("turbo-frame")
    const sourceFrame = state.frame
    const sourceChildren = state.children
    const parent = sourceFrame?.parentNode

    if (!targetFrame || !sourceFrame || !sourceChildren || !parent) return { undo: () => {} }

    const targetChildren = this.railContainer(target.dataset.folderId)
    const reference = move.beforeId ? targetFrame : targetChildren?.nextSibling ?? targetFrame.nextSibling
    if (reference === sourceFrame) return { undo: () => {} }

    parent.insertBefore(sourceFrame, reference)
    parent.insertBefore(sourceChildren, reference)

    return { undo: () => this.restoreFolder(state) }
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

  undoNoteMove(state) {
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
    if (state.folderId !== undefined) state.element.dataset.folderId = state.folderId
    this.setRootNote(state.element, state.root)
  }

  restoreFolder(state) {
    if (!state?.frame || !state.parent) return

    state.parent.insertBefore(state.frame, state.next)
    state.parent.insertBefore(state.children, state.next)
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

  reject(row) {
    row.classList.add("row--rejected")
    setTimeout(() => row.classList.remove("row--rejected"), 1200)
  }

  stateOf(element) {
    if (!element) return null

    return {
      element,
      parent: element.parentNode,
      next: element.nextSibling,
      root: element.classList.contains("row--root"),
      folderId: element.dataset.folderId
    }
  }

  folderState(folderId) {
    const row = this.folderRow(folderId)
    const frame = row?.closest("turbo-frame")
    const children = this.railContainer(folderId)

    return { frame, children, parent: frame?.parentNode, next: children?.nextSibling }
  }

  railNote(noteId) {
    return document.querySelector(`.rail .row--note[data-note-id="${noteId}"]`)
  }

  firstRailNote(folderId) {
    return Array.from(this.railContainer(folderId)?.querySelectorAll(".row--note") ?? [])
      .find(row => row.dataset.noteId !== this.source.id)
  }

  card(noteId) {
    return document.querySelector(`.board .card[data-note-id="${noteId}"]`)
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

  get headers() {
    return {
      "Content-Type": "application/x-www-form-urlencoded",
      "Accept": "application/json",
      "X-CSRF-Token": this.csrfToken
    }
  }

  get csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content
  }
}
