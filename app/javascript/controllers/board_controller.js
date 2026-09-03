import { Controller } from "@hotwired/stimulus"
import { formHeaders } from "request"

export default class extends Controller {
  static targets = ["notes", "pinnedSection", "pinnedGrid", "othersSection", "othersGrid", "othersHeading", "empty", "pinTemplate"]

  connect() {
    this.notes = new Map(JSON.parse(this.notesTarget.textContent).map(note => [note.id, note]))
  }

  note(id) {
    return this.notes.get(id)
  }

  saved({ detail: { note } }) {
    this.upsert(note)
  }

  discarded({ detail: { id } }) {
    this.remove(id)
  }

  preview({ detail: { note } }) {
    this.upsert(note)
  }

  synced({ detail: { note, id } }) {
    note ? this.upsert(note) : this.remove(id)
  }

  async togglePin(event) {
    event.preventDefault()
    event.stopPropagation()

    const card = event.target.closest(".card[data-note-id]")
    const note = this.note(card?.dataset.noteId)
    if (!note) return

    const pinned = !note.pinned
    this.upsert({ ...note, pinned })

    try {
      const response = await fetch(card.dataset.noteUrl, {
        method: "PATCH",
        headers: formHeaders(),
        body: new URLSearchParams({ "note[pinned]": pinned ? "1" : "0" }).toString()
      })

      if (!response.ok) throw new Error(`pin failed: ${response.status}`)
      this.upsert(await response.json())
    } catch (error) {
      this.upsert(note)
      console.error("[pin]", error)
    }
  }

  reordered({ detail: { notes } }) {
    notes.forEach(note => this.notes.set(note.id, note))
  }

  upsert(note) {
    const before = this.positions()
    const card = this.card(note.id)
    const adding = !card

    this.notes.set(note.id, note)
    this.updateRail(note)

    if (!this.belongsOnBoard(note)) {
      card?.remove()
      this.finishChange(before)
      return
    }

    const element = card || this.buildCard(note)
    this.renderCard(element, note)
    this.gridFor(note).append(element)
    this.sort(this.gridFor(note))
    this.finishChange(before, adding ? element : null)
  }

  remove(id) {
    const before = this.positions()
    this.notes.delete(id)
    this.card(id)?.remove()
    document.querySelector(`.rail .row--note[data-note-id="${CSS.escape(id)}"]`)?.remove()
    this.finishChange(before)
  }

  belongsOnBoard(note) {
    if (note.archived_at || note.deleted_at) return false

    const folderId = this.element.dataset.folderId || null
    return !folderId || note.folder_id === folderId
  }

  gridFor(note) {
    return note.pinned ? this.pinnedGridTarget : this.othersGridTarget
  }

  sort(grid) {
    const cards = Array.from(grid.querySelectorAll(".card[data-note-id]"))
    cards.sort((left, right) => this.compare(this.note(left.dataset.noteId), this.note(right.dataset.noteId)))
    cards.forEach(card => grid.append(card))
  }

  compare(left, right) {
    const folderBoard = Boolean(this.element.dataset.folderId)
    const leftPosition = folderBoard ? left.folder_board_position ?? left.board_position : left.board_position
    const rightPosition = folderBoard ? right.folder_board_position ?? right.board_position : right.board_position

    if (leftPosition != null && rightPosition != null) return leftPosition - rightPosition
    if (leftPosition != null) return -1
    if (rightPosition != null) return 1
    return right.updated_at.localeCompare(left.updated_at) || right.id.localeCompare(left.id)
  }

  buildCard(note) {
    const card = document.createElement("article")
    card.className = "card"
    card.id = `note_${note.id}`
    card.dataset.masonryTarget = "item"
    card.draggable = true
    return card
  }

  renderCard(card, note) {
    card.dataset.noteId = note.id
    card.dataset.noteUrl = note.url
    card.dataset.folderId = note.folder_id || ""
    card.dataset.pinned = note.pinned

    const open = document.createElement("a")
    open.className = "card__open"
    open.href = note.html_url
    open.draggable = false
    open.ariaLabel = `Edit ${note.title?.trim() || "untitled note"}`
    open.dataset.action = "click->modal#open"
    open.dataset.turbo = "false"
    open.dataset.turboPrefetch = "false"

    const children = [open, this.pinButton(note.pinned)]
    if (note.title) children.push(this.textElement("h3", "card__title", note.title))

    const preview = note.body?.split(/\r?\n/).slice(0, 12).join("\n").trim()
    if (preview) {
      children.push(this.textElement("p", "card__body", preview))
    } else if (!note.title && note.images.length === 0) {
      children.push(this.textElement("p", "card__empty", "Empty note"))
    }

    if (note.images.length > 0) children.push(this.thumbnails(note.images))

    const meta = document.createElement("div")
    meta.className = "card__meta"
    const folderName = this.folderName(note.folder_id)
    if (folderName) meta.append(this.textElement("span", "card__folder", folderName))

    const time = this.textElement("time", "card__time", this.relativeTime(note.updated_at))
    time.dateTime = note.updated_at
    time.title = new Date(note.updated_at).toLocaleString()
    meta.append(time)
    children.push(meta)

    card.replaceChildren(...children)
  }

  pinButton(pinned) {
    const button = this.pinTemplateTarget.content.firstElementChild.cloneNode(true)
    button.ariaPressed = String(pinned)
    button.title = pinned ? "Unpin" : "Pin"
    button.querySelector(".visually-hidden").textContent = button.title
    return button
  }

  thumbnails(images) {
    const strip = document.createElement("div")
    strip.className = "card__thumbs"

    images.slice(0, 3).forEach(image => {
      const thumbnail = document.createElement("img")
      thumbnail.className = "card__thumb"
      thumbnail.src = image.url
      thumbnail.alt = ""
      thumbnail.loading = "lazy"
      strip.append(thumbnail)
    })

    if (images.length > 3) strip.append(this.textElement("span", "card__thumb card__thumb-more", `+${images.length - 3}`))
    return strip
  }

  textElement(tag, className, text) {
    const element = document.createElement(tag)
    element.className = className
    element.textContent = text
    return element
  }

  folderName(id) {
    if (!id) return null
    return this.element.querySelector(`.editor__folder option[value="${CSS.escape(id)}"]`)?.textContent
  }

  relativeTime(timestamp) {
    const seconds = Math.round((new Date(timestamp).getTime() - Date.now()) / 1000)
    const formatter = new Intl.RelativeTimeFormat(undefined, { numeric: "auto" })
    if (Math.abs(seconds) < 60) return formatter.format(seconds, "second")
    if (Math.abs(seconds) < 3600) return formatter.format(Math.round(seconds / 60), "minute")
    if (Math.abs(seconds) < 86400) return formatter.format(Math.round(seconds / 3600), "hour")
    return formatter.format(Math.round(seconds / 86400), "day")
  }

  updateRail(note) {
    let row = document.querySelector(`.rail .row--note[data-note-id="${CSS.escape(note.id)}"]`)
    if (note.archived_at || note.deleted_at) return row?.remove()

    const container = note.folder_id
      ? document.querySelector(`.rail__children[data-folder-id="${CSS.escape(note.folder_id)}"]`)
      : document.querySelector(".rail__root-notes")
    if (!container) return

    if (!row) {
      row = document.createElement("a")
      row.className = "row row--note"
      row.draggable = true
      row.dataset.noteId = note.id
      row.dataset.noteUrl = note.url
      row.dataset.action = "dragenter->filing#over dragover->filing#over dragleave->filing#leave drop->filing#drop"
      row.append(this.textElement("span", "row__label", ""))
    }

    row.href = note.html_url
    row.dataset.folderId = note.folder_id || ""
    row.querySelector(".row__label").textContent = note.title?.trim() || note.body?.split(/\r?\n/)[0]?.trim() || "Untitled"

    const twist = row.querySelector(".row__twist")
    if (note.folder_id) {
      row.classList.remove("row--root")
      twist?.remove()
    } else {
      row.classList.add("row--root")
      if (!twist) {
        const spacer = this.textElement("span", "row__twist", "")
        spacer.ariaHidden = "true"
        row.prepend(spacer)
      }
    }

    if (row.parentElement !== container) container.prepend(row)
  }

  card(id) {
    return this.element.querySelector(`.card[data-note-id="${CSS.escape(id)}"]`)
  }

  positions() {
    return new Map(Array.from(this.element.querySelectorAll(".card[data-note-id]"), card => [card, card.getBoundingClientRect()]))
  }

  finishChange(before, added = null) {
    this.updateSections()
    this.layout(this.pinnedGridTarget)
    this.layout(this.othersGridTarget)

    requestAnimationFrame(() => {
      this.element.querySelectorAll(".card[data-note-id]").forEach(card => this.animate(card, before.get(card)))
      added?.animate(
        [{ opacity: 0, transform: "scale(0.96)" }, { opacity: 1, transform: "scale(1)" }],
        { duration: 160, easing: "cubic-bezier(0.2, 0, 0, 1)" }
      )
    })
  }

  updateSections() {
    const pinned = this.pinnedGridTarget.querySelector(".card")
    const others = this.othersGridTarget.querySelector(".card")
    this.pinnedSectionTarget.hidden = !pinned
    this.othersSectionTarget.hidden = !others
    this.emptyTarget.hidden = Boolean(pinned || others)
    this.othersHeadingTarget.textContent = pinned ? "Others" : "Notes"
  }

  layout(grid) {
    const masonry = this.application.getControllerForElementAndIdentifier(grid, "masonry")
    masonry ? masonry.layout() : grid.offsetHeight
  }

  animate(card, before) {
    if (!before) return
    const after = card.getBoundingClientRect()
    const dx = before.left - after.left
    const dy = before.top - after.top
    if (Math.abs(dx) < 1 && Math.abs(dy) < 1) return

    card.animate(
      [{ transform: `translate(${dx}px, ${dy}px)` }, { transform: "translate(0, 0)" }],
      { duration: 160, easing: "cubic-bezier(0.2, 0, 0, 1)" }
    )
  }
}
