import { Controller } from "@hotwired/stimulus"

// Disclosure in the sidebar tree. Expansion state lives in localStorage, and
// what's stored is the collapsed set — so a folder created later opens by
// default without migrating the stored value.
export default class extends Controller {
  static targets = ["children", "twist"]
  static values = { key: { type: String, default: "noted:tree:collapsed" } }

  connect() {
    this.collapsed = new Set(this.read())
    this.apply()

    // A morph syncs attributes against the server's markup, stripping the
    // `hidden` this controller set — so every collapsed folder springs open.
    // The rail survives the morph, so connect doesn't re-run; re-apply here.
    this.reapply = () => this.apply()
    addEventListener("turbo:morph", this.reapply)
    addEventListener("turbo:render", this.reapply)
  }

  disconnect() {
    removeEventListener("turbo:morph", this.reapply)
    removeEventListener("turbo:render", this.reapply)
  }

  toggle(event) {
    const id = event.currentTarget.dataset.folderId

    this.collapsed.has(id) ? this.collapsed.delete(id) : this.collapsed.add(id)
    this.write()
    this.apply()
  }

  apply() {
    this.childrenTargets.forEach((children) => {
      // A collapsed folder still opens while it holds the current note, so the
      // sidebar can show where you are. Stored state is left alone.
      const holdsCurrent = children.querySelector("[aria-current]") !== null

      children.hidden = this.collapsed.has(children.dataset.folderId) && !holdsCurrent
    })

    this.twistTargets.forEach((twist) => {
      const children = this.childrenFor(twist.dataset.folderId)

      twist.setAttribute("aria-expanded", String(children ? !children.hidden : true))
    })
  }

  childrenFor(id) {
    return this.childrenTargets.find((children) => children.dataset.folderId === id)
  }

  read() {
    try {
      const stored = JSON.parse(localStorage.getItem(this.keyValue))
      return Array.isArray(stored) ? stored : []
    } catch {
      return []
    }
  }

  write() {
    try {
      localStorage.setItem(this.keyValue, JSON.stringify([...this.collapsed]))
    } catch {
      // Private browsing or full quota: the tree still works, it just forgets.
    }
  }
}
