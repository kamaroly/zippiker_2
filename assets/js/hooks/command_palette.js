// Command search (⌘K / Ctrl+K): filters the server-rendered list of pages and
// actions as you type; ↑/↓ to move, Enter to go, Esc to close.
const normalize = (text) => text.toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "")

export default {
  mounted() {
    this.dialog = this.el.querySelector("[data-palette-dialog]")
    this.input = this.el.querySelector("[data-palette-input]")
    this.items = Array.from(this.el.querySelectorAll("[data-palette-item]"))
    this.empty = this.el.querySelector("[data-palette-empty]")
    this.active = 0

    this.onKey = (e) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") {
        e.preventDefault()
        this.isOpen() ? this.close() : this.open()
      } else if (this.isOpen()) {
        if (e.key === "Escape") this.close()
        if (e.key === "ArrowDown") { e.preventDefault(); this.move(1) }
        if (e.key === "ArrowUp") { e.preventDefault(); this.move(-1) }
        if (e.key === "Enter") { e.preventDefault(); this.go() }
      }
    }
    window.addEventListener("keydown", this.onKey)

    this.el.querySelectorAll("[data-palette-open]").forEach((el) => el.addEventListener("click", () => this.open()))
    this.el.querySelector("[data-palette-backdrop]").addEventListener("click", () => this.close())
    this.input.addEventListener("input", () => this.filter())
    this.items.forEach((item) => item.addEventListener("click", () => this.close()))
  },

  destroyed() { window.removeEventListener("keydown", this.onKey) },

  isOpen() { return !this.dialog.classList.contains("hidden") },

  open() {
    this.dialog.classList.remove("hidden")
    this.input.value = ""
    this.filter()
    this.input.focus()
  },

  close() { this.dialog.classList.add("hidden") },

  visible() { return this.items.filter((item) => !item.classList.contains("hidden")) },

  filter() {
    const words = normalize(this.input.value).split(/\s+/).filter(Boolean)
    this.items.forEach((item) => {
      const text = normalize(item.dataset.search)
      item.classList.toggle("hidden", !words.every((word) => text.includes(word)))
    })
    this.empty.classList.toggle("hidden", this.visible().length > 0)
    this.active = 0
    this.highlight()
  },

  move(step) {
    const count = this.visible().length
    if (count === 0) return
    this.active = (this.active + step + count) % count
    this.highlight()
  },

  highlight() {
    this.visible().forEach((item, index) => {
      item.classList.toggle("bg-canvas", index === this.active)
      if (index === this.active) item.scrollIntoView({block: "nearest"})
    })
  },

  go() {
    const item = this.visible()[this.active]
    if (item) item.click()
  }
}
