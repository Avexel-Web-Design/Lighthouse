import { Controller } from "@hotwired/stimulus"

// Sorts table rows by clicking column headers.
// Each <th> needs data-action="click->sortable-table#sort" and data-col="<index>".
// Each <td> that should be sortable needs data-sort-value="<numeric or string value>".

export default class extends Controller {
  static targets = ["body"]

  connect() {
    this.currentCol = null
    this.ascending = true
    this.element.querySelectorAll("th[data-col]").forEach(header => {
      header.tabIndex = 0
      header.setAttribute("aria-sort", "none")
    })
    this._keydown = event => {
      const header = event.target.closest("th[data-col]")
      if (!header || !["Enter", " "].includes(event.key)) return
      event.preventDefault()
      this.sort({ currentTarget: header })
    }
    this.element.addEventListener("keydown", this._keydown)
  }

  disconnect() {
    this.element.removeEventListener("keydown", this._keydown)
  }

  sort(event) {
    const th = event.currentTarget
    const col = parseInt(th.dataset.col, 10)

    // Toggle direction if clicking the same column
    if (this.currentCol === col) {
      this.ascending = !this.ascending
    } else {
      this.currentCol = col
      this.ascending = true
    }

    // Update header indicators + aria-sort (not color/icon-only)
    this.element.querySelectorAll("th[data-col]").forEach(header => {
      const arrow = header.querySelector("[data-sort-arrow]")
      const isActive = parseInt(header.dataset.col, 10) === col
      header.setAttribute("aria-sort", isActive ? (this.ascending ? "ascending" : "descending") : "none")
      if (!arrow) return
      if (isActive) {
        arrow.textContent = this.ascending ? " ▲" : " ▼"
        arrow.classList.remove("invisible")
        arrow.setAttribute("aria-hidden", "true")
      } else {
        arrow.textContent = " ▲"
        arrow.classList.add("invisible")
      }
    })

    const tbody = this.bodyTarget
    const rows = Array.from(tbody.querySelectorAll("tr"))

    rows.sort((a, b) => {
      const aCell = a.querySelectorAll("td")[col]
      const bCell = b.querySelectorAll("td")[col]
      const aVal = aCell?.dataset.sortValue ?? aCell?.textContent.trim() ?? ""
      const bVal = bCell?.dataset.sortValue ?? bCell?.textContent.trim() ?? ""

      const aNum = parseFloat(aVal)
      const bNum = parseFloat(bVal)

      let result
      if (!isNaN(aNum) && !isNaN(bNum)) {
        result = aNum - bNum
      } else {
        result = aVal.localeCompare(bVal, undefined, { numeric: true })
      }

      return this.ascending ? result : -result
    })

    rows.forEach(row => tbody.appendChild(row))
  }
}
