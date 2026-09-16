import { Controller } from "@hotwired/stimulus"
import { showToast } from "lib/toast"

/**
 * Prevents form submissions and destructive actions when the user is offline.
 * Used on non-scouting forms that require server connectivity.
 *
 * Usage on forms:
 *   <form data-controller="offline-guard" data-action="submit->offline-guard#check">
 *
 * Usage on button_to (wraps in a form):
 *   Add via the form: option on button_to, or wrap with a parent div.
 */
export default class extends Controller {
  check(event) {
    if (!navigator.onLine) {
      event.preventDefault()
      event.stopImmediatePropagation()
      this.#showOfflineWarning()
    }
  }

  #showOfflineWarning() {
    // Shared toast (textContent-only, role=alert) into #toast-stack so the
    // offline-guard never stacks a second fixed banner over connectivity's.
    showToast("This action requires an internet connection.", { type: "error" })
  }
}
