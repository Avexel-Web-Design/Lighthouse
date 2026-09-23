import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "count", "list", "row", "selectedList", "toggle"]

  connect() {
    this.refresh()
  }

  refresh() {
    const selectedIds = this.#selectedIds()
    this.countTarget.textContent = `${selectedIds.length} selected`

    this.rowTargets.forEach(row => {
      const checkbox = this.#checkboxFor(row.dataset.teamId)
      const selected = checkbox?.checked
      row.classList.toggle("bg-orange-500/10", selected)
      row.classList.toggle("hover:bg-orange-500/15", selected)
      row.classList.toggle("hover:bg-gray-800/40", !selected)

      const button = this.#toggleFor(row.dataset.teamId)
      if (button) {
        button.textContent = selected ? "Added" : "Add"
        button.className = selected
          ? "rounded-lg px-3 py-1.5 text-xs font-semibold bg-orange-500/20 text-orange-300 border border-orange-500/30 transition-colors duration-150"
          : "rounded-lg px-3 py-1.5 text-xs font-semibold bg-gray-800 text-gray-300 border border-gray-700 hover:border-orange-500/30 hover:text-orange-300 transition-colors duration-150"
      }
    })

    if (selectedIds.length === 0) {
      this.selectedListTarget.replaceChildren(this.#emptyState())
      return
    }

    const chips = this.rowTargets
      .filter(row => this.#checkboxFor(row.dataset.teamId)?.checked)
      .map(row => this.#selectedChip(row.dataset.teamId, row.dataset.teamLabel))

    this.selectedListTarget.replaceChildren(...chips)
  }

  toggleTeam(event) {
    const teamId = event.currentTarget.dataset.teamId
    const checkbox = this.#checkboxFor(teamId)
    if (!checkbox) return

    checkbox.checked = !checkbox.checked
    this.refresh()
  }

  removeSelected(event) {
    const teamId = event.currentTarget.dataset.teamId
    const checkbox = this.#checkboxFor(teamId)
    if (!checkbox) return

    checkbox.checked = false
    this.refresh()
  }

  clearSelection() {
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = false
    })

    this.refresh()
  }

  sortRows(event) {
    const metric = event.currentTarget.value
    const rows = [...this.rowTargets]

    rows.sort((left, right) => this.#compareRows(left, right, metric))
    this.listTarget.replaceChildren(...rows)
  }

  #selectedIds() {
    return this.checkboxTargets.filter(checkbox => checkbox.checked).map(checkbox => checkbox.value)
  }

  #checkboxFor(teamId) {
    return this.checkboxTargets.find(checkbox => checkbox.value === String(teamId))
  }

  #toggleFor(teamId) {
    return this.toggleTargets.find(button => button.dataset.teamId === String(teamId))
  }

  #compareRows(left, right, metric) {
    if (metric === "team_number") {
      return Number(left.dataset.teamNumber || 0) - Number(right.dataset.teamNumber || 0)
    }

    const leftValue = Number(left.dataset[metric] || -1)
    const rightValue = Number(right.dataset[metric] || -1)

    if (leftValue === rightValue) {
      return Number(left.dataset.teamNumber || 0) - Number(right.dataset.teamNumber || 0)
    }

    return rightValue - leftValue
  }

  #emptyState() {
    const text = document.createElement("p")
    text.className = "text-sm text-gray-400"
    text.textContent = "No teams selected yet."
    return text
  }

  #selectedChip(teamId, label) {
    const button = document.createElement("button")
    button.type = "button"
    button.className = "inline-flex items-center gap-2 rounded-full border border-orange-500/30 bg-orange-500/10 px-3 py-1 text-xs font-medium text-orange-200"
    button.dataset.action = "click->pick-list-selection#removeSelected"
    button.dataset.teamId = teamId

    const labelSpan = document.createElement("span")
    labelSpan.textContent = label
    button.appendChild(labelSpan)

    const closeSpan = document.createElement("span")
    closeSpan.setAttribute("aria-hidden", "true")
    closeSpan.textContent = "×"
    button.appendChild(closeSpan)

    return button
  }
}
