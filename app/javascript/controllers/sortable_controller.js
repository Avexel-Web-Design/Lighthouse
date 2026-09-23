import { Controller } from "@hotwired/stimulus"
import { showToast } from "lib/toast"

export default class extends Controller {
  static targets = ["item", "list", "rank"]

  static tierClassNames = [
    "bg-amber-500/20",
    "border-amber-500/30",
    "text-amber-400",
    "bg-orange-500/20",
    "border-orange-500/30",
    "text-orange-400",
    "bg-blue-500/20",
    "border-blue-500/30",
    "text-blue-400",
    "bg-gray-500/20",
    "border-gray-500/30",
    "text-gray-400"
  ]

  connect() {
    this.draggedItem = null
    this.placeholder = null
    this.#enableDragging()
    this.#enablePointerDragging()
  }

  // --- HTML5 Drag Events (Desktop) ---

  dragstart(event) {
    this.draggedItem = event.currentTarget
    event.currentTarget.classList.add("opacity-50", "scale-[0.98]")
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", event.currentTarget.dataset.sortableId)
    this.#createPlaceholder()
  }

  dragover(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"

    const target = event.target.closest("[data-sortable-target='item']")
    if (!target) {
      const list = this.hasListTarget ? this.listTarget : this.element
      list.appendChild(this.placeholder)
      return
    }

    if (target === this.draggedItem || target === this.placeholder) return

    this.#positionPlaceholder(target, event.clientY)
  }

  drop(event) {
    event.preventDefault()
    this.#finalizeDrop()
  }

  dragend(event) {
    event.currentTarget.classList.remove("opacity-50", "scale-[0.98]")
    this.#removePlaceholder()
    this.draggedItem = null
  }

  // --- Pointer Events (Touch + Mouse fallback) ---

  #enablePointerDragging() {
    this.itemTargets.forEach(item => {
      const handle = item.querySelector("[data-sortable-handle]") || item
      handle.addEventListener("pointerdown", (e) => this.#onPointerDown(e, item))
    })
  }

  #onPointerDown(event, item) {
    // Only handle touch events (let HTML5 drag handle mouse)
    if (event.pointerType === "mouse") return

    event.preventDefault()
    this.draggedItem = item
    this.touchStartY = event.clientY
    this.itemHeight = item.offsetHeight

    // Visual feedback
    item.classList.add("opacity-50", "scale-[0.98]", "z-10", "relative")
    this.#createPlaceholder()

    const onPointerMove = (e) => {
      e.preventDefault()
      const target = document.elementFromPoint(e.clientX, e.clientY)?.closest("[data-sortable-target='item']")
      if (target && target !== this.draggedItem && target !== this.placeholder) {
        this.#positionPlaceholder(target, e.clientY)
      }
    }

    const onPointerUp = () => {
      document.removeEventListener("pointermove", onPointerMove)
      document.removeEventListener("pointerup", onPointerUp)
      item.classList.remove("opacity-50", "scale-[0.98]", "z-10", "relative")
      this.#finalizeDrop()
      this.draggedItem = null
    }

    document.addEventListener("pointermove", onPointerMove, { passive: false })
    document.addEventListener("pointerup", onPointerUp, { once: true })
  }

  // --- Shared Helpers ---

  #createPlaceholder() {
    if (this.placeholder) return
    this.placeholder = document.createElement("div")
    this.placeholder.className = "h-1 bg-orange-500 rounded-full mx-4 my-1 transition-all duration-150 shadow-sm shadow-orange-500/30"
    this.placeholder.dataset.placeholder = "true"
  }

  #positionPlaceholder(target, clientY) {
    if (!this.placeholder || !this.draggedItem) return

    const rect = target.getBoundingClientRect()
    const midY = rect.top + rect.height / 2
    const list = this.hasListTarget ? this.listTarget : this.element

    if (clientY < midY) {
      list.insertBefore(this.placeholder, target)
    } else {
      target.after(this.placeholder)
    }
  }

  #removePlaceholder() {
    if (this.placeholder && this.placeholder.parentNode) {
      this.placeholder.parentNode.removeChild(this.placeholder)
    }
    this.placeholder = null
  }

  #finalizeDrop() {
    if (this.placeholder && this.placeholder.parentNode && this.draggedItem) {
      this.placeholder.parentNode.insertBefore(this.draggedItem, this.placeholder)
    }
    this.#removePlaceholder()
    this.#updateRankNumbers()
    this.#saveOrder()
  }

  #enableDragging() {
    this.itemTargets.forEach(item => {
      item.setAttribute("draggable", "true")
    })
  }

  moveUp(event) {
    event.preventDefault()
    const item = event.currentTarget.closest("[data-sortable-target='item']")
    if (!item) return

    const previousItem = item.previousElementSibling
    if (!previousItem) return

    previousItem.before(item)
    this.#updateRankNumbers()
    this.#saveOrder()
  }

  moveDown(event) {
    event.preventDefault()
    const item = event.currentTarget.closest("[data-sortable-target='item']")
    if (!item) return

    const nextItem = item.nextElementSibling
    if (!nextItem) return

    nextItem.after(item)
    this.#updateRankNumbers()
    this.#saveOrder()
  }

  sortBy(event) {
    const metric = event.currentTarget.value
    if (!metric) return

    const list = this.hasListTarget ? this.listTarget : this.element
    const items = [...list.querySelectorAll("[data-sortable-target='item']")]

    items.sort((left, right) => this.#compareItems(left, right, metric))
    list.append(...items)
    this.#updateRankNumbers()
    this.#saveOrder()
  }

  #updateRankNumbers() {
    const list = this.hasListTarget ? this.listTarget : this.element
    const items = [...list.querySelectorAll("[data-sortable-target='item']")]
    items.forEach((item, index) => {
      const rankEl = item.querySelector("[data-sortable-target='rank']")
      if (rankEl) {
        rankEl.textContent = index + 1
        rankEl.classList.remove(...this.constructor.tierClassNames)
        rankEl.classList.add(...this.#tierClassesForIndex(index))
        // Brief highlight animation
        rankEl.classList.add("animate-bounce-number")
        rankEl.addEventListener("animationend", () => {
          rankEl.classList.remove("animate-bounce-number")
        }, { once: true })
      }
    })
  }

  #tierClassesForIndex(index) {
    if (index <= 7) {
      return ["bg-amber-500/20", "border-amber-500/30", "text-amber-400"]
    }

    if (index <= 15) {
      return ["bg-orange-500/20", "border-orange-500/30", "text-orange-400"]
    }

    if (index <= 23) {
      return ["bg-blue-500/20", "border-blue-500/30", "text-blue-400"]
    }

    return ["bg-gray-500/20", "border-gray-500/30", "text-gray-400"]
  }

  #compareItems(left, right, metric) {
    if (metric === "teamNumber") {
      return Number(left.dataset.teamNumber || 0) - Number(right.dataset.teamNumber || 0)
    }

    const leftValue = Number(left.dataset[metric] || -1)
    const rightValue = Number(right.dataset[metric] || -1)

    if (leftValue === rightValue) {
      return Number(left.dataset.teamNumber || 0) - Number(right.dataset.teamNumber || 0)
    }

    return rightValue - leftValue
  }

  async #saveOrder() {
    const list = this.hasListTarget ? this.listTarget : this.element
    const items = [...list.querySelectorAll("[data-sortable-target='item']")]
    const orderedIds = items.map(item => item.dataset.sortableId)

    // Update hidden field if present
    const hiddenField = this.element.querySelector("[data-sortable-order]")
    if (hiddenField) {
      hiddenField.value = JSON.stringify(orderedIds)
    }

    // Auto-save via PATCH if a save URL is configured.
    // Raw fetch (not a Turbo visit) on purpose: this is a JSON API call that
    // must not trigger Turbo Drive navigation or cache invalidation. It still
    // respects Turbo by sending the CSRF token + same-origin credentials and
    // accepting JSON only, matching PickListsController#update format.json.
    const url = this.element.dataset.sortableSaveUrl
    if (!url) return

    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content

    try {
      const response = await fetch(url, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken || "",
          "Accept": "application/json"
        },
        credentials: "same-origin",
        body: JSON.stringify({ entries: orderedIds })
      })

      if (response.ok) {
        showToast("Order saved", { type: "success", duration: 2000 })
      } else {
        showToast("Failed to save order", { type: "error", duration: 2000 })
      }
    } catch (error) {
      console.error("[Lighthouse] Failed to save sort order:", error)
      showToast("Failed to save order", { type: "error", duration: 2000 })
    }
  }
}
