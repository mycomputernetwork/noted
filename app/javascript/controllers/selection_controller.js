import { Controller } from "@hotwired/stimulus"
import { formHeaders } from "request"

export default class extends Controller {
  static targets = ["toolbar", "count", "toast", "toastMessage", "undoButton"]

  connect() {
    this.selected = new Set()
    this.escape = event => {
      if (event.key === "Escape" && this.selected.size > 0) this.clear()
    }
    this.beforeCache = () => this.clear()
    this.closeMenus = event => {
      this.element.querySelectorAll(".card__menu[open], .selection-menu[open]").forEach(menu => {
        if (!menu.contains(event.target)) menu.removeAttribute("open")
      })
    }
    this.observer = new MutationObserver(() => this.reconcile())
    this.observer.observe(this.element, { childList: true, subtree: true })
    addEventListener("click", this.closeMenus)
    addEventListener("keydown", this.escape)
    addEventListener("turbo:before-cache", this.beforeCache)
  }

  disconnect() {
    this.element.classList.remove("shell--selecting")
    this.observer?.disconnect()
    clearTimeout(this.toastTimer)
    removeEventListener("click", this.closeMenus)
    removeEventListener("keydown", this.escape)
    removeEventListener("turbo:before-cache", this.beforeCache)
  }

  toggle(event) {
    event.stopPropagation()
    const card = event.target.closest(".card[data-note-id]")
    if (card) this.select(card, event.target.checked)
  }

  open(event) {
    if (this.selected.size === 0) return

    event.preventDefault()
    event.stopImmediatePropagation()
    const card = event.target.closest(".card[data-note-id]")
    if (card) this.select(card, !this.selected.has(card.dataset.noteId))
  }

  clear() {
    this.selected.clear()
    this.cards.forEach(card => this.mark(card, false))
    this.updateToolbar()
  }

  reconcile() {
    const cards = this.cards
    const ids = new Set(cards.map(card => card.dataset.noteId))
    this.selected.forEach(id => { if (!ids.has(id)) this.selected.delete(id) })
    cards.forEach(card => this.mark(card, this.selected.has(card.dataset.noteId)))
    this.updateToolbar()
  }

  async deleteOne(event) {
    event.preventDefault()
    const card = event.target.closest(".card[data-note-id]")
    if (!card) return

    event.target.closest("details")?.removeAttribute("open")
    await this.deleteCards([card])
  }

  async deleteSelected(event) {
    event.preventDefault()
    event.target.closest("details")?.removeAttribute("open")
    const cards = this.cards.filter(card => this.selected.has(card.dataset.noteId))
    await this.deleteCards(cards)
  }

  select(card, selected) {
    if (selected) this.selected.add(card.dataset.noteId)
    else this.selected.delete(card.dataset.noteId)

    this.mark(card, selected)
    this.updateToolbar()
  }

  mark(card, selected) {
    card.classList.toggle("card--selected", selected)
    const input = card.querySelector(".card__select input")
    if (input) input.checked = selected
  }

  updateToolbar() {
    const count = this.selected.size
    this.element.classList.toggle("shell--selecting", count > 0)
    this.cards.forEach(card => { card.draggable = count === 0 })
    if (!this.hasToolbarTarget) return

    this.toolbarTarget.hidden = count === 0
    const label = `${count} selected`
    if (this.hasCountTarget && this.countTarget.textContent !== label) this.countTarget.textContent = label
  }

  async deleteCards(cards) {
    const results = await Promise.all(cards.map(card => this.delete(card)))
    const deleted = results.filter(result => result.ok)
    const ids = deleted.map(result => result.note.id)
    const failures = results.length - deleted.length

    ids.forEach(id => this.selected.delete(id))
    this.boardElement?.dispatchEvent(new CustomEvent("selection:deleted", { detail: { ids } }))
    if (deleted.length > 0) {
      Turbo.cache.clear()
      this.showUndo(deleted.map(result => result.note), failures)
    } else if (failures > 0) {
      this.announce(failures === 1 ? "Couldn’t delete the note." : `Couldn’t delete ${failures} notes.`)
    }
    this.updateToolbar()
  }

  async delete(card) {
    const note = this.board?.note(card.dataset.noteId)
    if (!note) return { ok: false }

    try {
      const response = await fetch(card.dataset.noteUrl, {
        method: "DELETE",
        headers: formHeaders()
      })
      if (!response.ok) throw new Error(`delete failed: ${response.status}`)

      return { ok: true, note }
    } catch (error) {
      console.error("[selection]", error)
      return { ok: false }
    }
  }

  async undo(event) {
    event.preventDefault()
    const notes = this.undoable || []
    if (notes.length === 0) return

    clearTimeout(this.toastTimer)
    this.undoButtonTarget.disabled = true
    const results = await Promise.all(notes.map(note => this.restore(note)))
    const restored = results.filter(Boolean)
    this.undoButtonTarget.disabled = false

    if (restored.length > 0) {
      this.boardElement?.dispatchEvent(new CustomEvent("selection:restored", { detail: { notes: restored } }))
      Turbo.cache.clear()
    }

    const failures = notes.length - restored.length
    if (failures > 0) {
      this.announce(failures === 1 ? "Couldn’t restore the note." : `Couldn’t restore ${failures} notes.`)
    } else {
      this.hideToast()
    }
  }

  async restore(note) {
    try {
      const response = await fetch(`${note.url}/restore`, {
        method: "PATCH",
        headers: formHeaders()
      })
      if (!response.ok) throw new Error(`restore failed: ${response.status}`)
      return response.json()
    } catch (error) {
      console.error("[selection]", error)
      return null
    }
  }

  showUndo(notes, failures = 0) {
    if (!this.hasToastTarget) return

    clearTimeout(this.toastTimer)
    this.undoable = notes
    const message = notes.length === 1 ? "Note trashed" : `${notes.length} notes trashed`
    this.toastMessageTarget.textContent = failures > 0 ? `${message}; ${failures} failed` : message
    this.undoButtonTarget.hidden = false
    this.toastTarget.hidden = false
    this.toastTimer = setTimeout(() => this.hideToast(), 5000)
  }

  announce(message) {
    if (!this.hasToastTarget) return

    clearTimeout(this.toastTimer)
    this.undoable = null
    this.toastMessageTarget.textContent = message
    this.undoButtonTarget.hidden = true
    this.toastTarget.hidden = false
    this.toastTimer = setTimeout(() => this.hideToast(), 3000)
  }

  hideToast() {
    if (this.hasToastTarget) this.toastTarget.hidden = true
    this.undoable = null
  }

  get boardElement() {
    return this.element.querySelector("[data-controller~='board']")
  }

  get board() {
    return this.application.getControllerForElementAndIdentifier(this.boardElement, "board")
  }

  get cards() {
    return Array.from(this.element.querySelectorAll(".card[data-note-id]"))
  }
}
