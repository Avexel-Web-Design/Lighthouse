import { Controller } from "@hotwired/stimulus"
import { openDB, PIT_STORE } from "lib/lighthouse_db"
import { showToast } from "lib/toast"

/**
 * Handles offline form submission for pit scouting entries.
 * When offline, intercepts the form submit, saves the entry to IndexedDB,
 * and shows a confirmation banner. When online, allows normal form submission.
 *
 * Usage:
 *   <form data-controller="pit-scouting" data-action="submit->pit-scouting#submitForm">
 */
export default class extends Controller {
  submitForm(event) {
    // Serialize auton paths data before submission
    this.#serializeAutonPaths()

    if (navigator.onLine) return // Allow normal submission when online

    event.preventDefault()
    this.#saveToOfflineQueue()
  }

  async #saveToOfflineQueue() {
    try {
      const form = this.element
      const formData = new FormData(form)

      // Build the data object from form fields
      const data = {}
      const dataPrefix = "pit_scouting_entry[data]"

      for (const [key, value] of formData.entries()) {
        // Extract data[field_name] entries
        if (key.startsWith(dataPrefix)) {
          const fieldMatch = key.match(/\[data\]\[(\w+)\](\[\])?$/)
          if (fieldMatch) {
            const fieldName = fieldMatch[1]
            const isArray = fieldMatch[2] === "[]"

            if (isArray) {
              if (!data[fieldName]) data[fieldName] = []
              if (value) data[fieldName].push(value)
            } else {
              data[fieldName] = value
            }
          }
        }
      }

      const entry = {
        client_uuid: crypto.randomUUID(),
        frc_team_id: formData.get("pit_scouting_entry[frc_team_id]") || null,
        event_id: formData.get("pit_scouting_entry[event_id]") || this.#extractEventId(),
        organization_id: formData.get("pit_scouting_entry[organization_id]") || null,
        notes: formData.get("pit_scouting_entry[notes]") || "",
        data: data,
        created_at: new Date().toISOString()
      }

      const db = await openDB()
      const tx = db.transaction(PIT_STORE, "readwrite")
      tx.objectStore(PIT_STORE).add(entry)
      await new Promise((resolve, reject) => {
        tx.oncomplete = resolve
        tx.onerror = () => reject(tx.error)
      })

      db.close()

      this.#showOfflineConfirmation()

      // Dispatch event so connectivity controller can update the queue count
      window.dispatchEvent(new CustomEvent("lighthouse:entry-queued"))
    } catch (error) {
      console.error("[Lighthouse] Failed to save pit scouting entry offline:", error)
      alert("Failed to save entry offline. Please try again.")
    }
  }

  #serializeAutonPaths() {
    // Find the auton-paths controller and trigger serialization
    const autonPathsEl = this.element.querySelector("[data-controller*='auton-paths']")
    if (autonPathsEl) {
      const autonPathsController = this.application.getControllerForElementAndIdentifier(autonPathsEl, "auton-paths")
      if (autonPathsController) autonPathsController.serialize()
    }
  }

  #extractEventId() {
    // Try to find event_id from a hidden field or meta tag
    const hiddenField = this.element.querySelector("[name*='event_id']")
    if (hiddenField) return hiddenField.value

    const meta = document.querySelector("meta[name='current-event-id']")
    if (meta) return meta.content

    return null
  }

  #showOfflineConfirmation() {
    // Shared toast (textContent-only, role=status) into the
    // connectivity-owned #toast-stack — no duplicate fixed banners.
    showToast("Pit scout saved offline. It will sync when you reconnect. Photos must be added after syncing.", { type: "info", duration: 5000 })
  }
}
