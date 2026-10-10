// Native HTML5 drag & drop for the deal board. No library needed.
// Cards carry data-deal-id / data-position; columns carry data-stage-id.
// On drop we compute a position between the neighbours and let the server
// persist it; the card is moved immediately so the UI feels instant.
const Board = {
  mounted() {
    this.dragged = null

    this.el.addEventListener("dragstart", e => {
      const card = e.target.closest("[data-deal-id]")
      if (!card) return
      this.dragged = card
      card.classList.add("dragging")
      e.dataTransfer.effectAllowed = "move"
      e.dataTransfer.setData("text/plain", card.dataset.dealId)
    })

    this.el.addEventListener("dragend", () => {
      this.dragged?.classList.remove("dragging")
      this.dragged = null
      this.clearTargets()
    })

    this.el.addEventListener("dragover", e => {
      const column = e.target.closest("[data-stage-id]")
      if (!column || !this.dragged) return
      e.preventDefault()
      if (!column.classList.contains("drop-target")) {
        this.clearTargets()
        column.classList.add("drop-target")
      }
    })

    this.el.addEventListener("drop", e => {
      const column = e.target.closest("[data-stage-id]")
      if (!column || !this.dragged) return
      e.preventDefault()

      const list = column.querySelector("[data-deal-list]")
      const cards = [...list.querySelectorAll("[data-deal-id]")].filter(c => c !== this.dragged)
      const after = cards.find(c => {
        const rect = c.getBoundingClientRect()
        return e.clientY < rect.top + rect.height / 2
      })
      const index = after ? cards.indexOf(after) : cards.length
      const prev = index > 0 ? parseFloat(cards[index - 1].dataset.position) : null
      const next = after ? parseFloat(after.dataset.position) : null

      let position = 0
      if (prev !== null && next !== null) position = (prev + next) / 2
      else if (prev !== null) position = prev + 1024
      else if (next !== null) position = next - 1024

      const id = this.dragged.dataset.dealId
      list.insertBefore(this.dragged, after || null)
      this.clearTargets()
      this.pushEvent("move", {id, stage_id: column.dataset.stageId, position})
    })
  },

  clearTargets() {
    this.el.querySelectorAll(".drop-target").forEach(el => el.classList.remove("drop-target"))
  }
}

export default Board
