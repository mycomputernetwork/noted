import { Controller } from "@hotwired/stimulus"

// Disclosure in the sidebar tree (PRD §7.6).
//
// Expansion state is interface state, not user data: which folders happen to
// be open is a property of this browser and nobody else's business, so it
// lives in localStorage rather than in a column. Losing it costs one click.
//
// Collapsed folders are what is stored, not expanded ones. A folder created
// later should appear open — a new folder that hides itself is a folder you
// have to discover twice — and storing the exception rather than the rule is
// what makes that the default without a migration of the stored set.
export default class extends Controller {
  static targets = ["children", "twist"]
  static values = { key: { type: String, default: "notbuk:tree:collapsed" } }

  connect() {
    this.collapsed = new Set(this.read())
    this.apply()
  }

  toggle(event) {
    const id = event.currentTarget.dataset.folderId

    this.collapsed.has(id) ? this.collapsed.delete(id) : this.collapsed.add(id)
    this.write()
    this.apply()
  }

  apply() {
    this.childrenTargets.forEach((children) => {
      // A collapsed folder still opens if the note you are looking at is
      // inside it. The sidebar's job is to say where you are (§7.6), and it
      // cannot do that from behind a closed triangle. The stored state is
      // left alone, so the folder closes again when you leave.
      const holdsCurrent = children.querySelector("[aria-current]") !== null

      children.hidden = this.collapsed.has(children.dataset.folderId) && !holdsCurrent
    })

    this.twistTargets.forEach((twist) => {
      const children = this.childrenFor(twist.dataset.folderId)
      const open = children ? !children.hidden : true

      twist.setAttribute("aria-expanded", String(open))
      twist.querySelector("[aria-hidden]").textContent = open ? "▾" : "▸"
    })
  }

  childrenFor(id) {
    return this.childrenTargets.find((children) => children.dataset.folderId === id)
  }

  // A corrupt or absent entry is not worth handling twice: either way the
  // tree opens fully, which is the state it would have had anyway.
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
      // Private browsing, a full quota — the tree still works, it just
      // forgets. Nothing here is worth an error for.
    }
  }
}
