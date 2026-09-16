import { Controller } from "@hotwired/stimulus"

// Manages bulk selection of members for role changes and removal.
// Targets:
//   checkbox       - individual member checkboxes
//   bulkActions    - the bulk actions bar (shown/hidden)
//   selectedCount  - text showing "N selected"
//   bulkUpdateIds  - container for hidden inputs in the bulk update form
//   bulkDestroyIds - container for hidden inputs in the bulk destroy form
//   bulkUpdateForm - the bulk update form element
//   bulkDestroyForm - the bulk destroy form element
export default class extends Controller {
  static targets = [
    "checkbox",
    "bulkActions",
    "selectedCount",
    "bulkUpdateIds",
    "bulkDestroyIds",
    "bulkUpdateForm",
    "bulkDestroyForm"
  ]

  toggle() {
    this.syncSelectedIds()
  }

  // Gather selected IDs and update UI
  syncSelectedIds() {
    const selectedIds = this.checkboxTargets
      .filter(cb => cb.checked)
      .map(cb => cb.value)

    const count = selectedIds.length

    // Show/hide bulk actions bar
    if (this.hasBulkActionsTarget) {
      this.bulkActionsTarget.style.display = count > 0 ? "flex" : "none"
    }

    // Update selected count text
    if (this.hasSelectedCountTarget) {
      this.selectedCountTarget.textContent = `${count} selected`
    }

    // Sync hidden inputs into both bulk forms
    if (this.hasBulkUpdateIdsTarget) {
      this.syncHiddenInputs(this.bulkUpdateIdsTarget, selectedIds)
    }
    if (this.hasBulkDestroyIdsTarget) {
      this.syncHiddenInputs(this.bulkDestroyIdsTarget, selectedIds)
    }
  }

  // Replace all hidden inputs inside a container with the given IDs
  syncHiddenInputs(container, ids) {
    if (!container) return

    // replaceChildren (not innerHTML="") so existing nodes/values are
    // dropped without ever parsing HTML.
    container.replaceChildren()
    ids.forEach(id => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "membership_ids[]"
      input.value = id
      container.appendChild(input)
    })
  }
}
