import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Tailwind-only animation (no inline styles): .toast-card starts hidden,
    // .toast-visible slides in. Works with Turbo Drive + Turbo Frames because
    // Stimulus reconnects on every frame render and dismiss() only removes
    // this element — never the surrounding turbo-frame.
    this.element.classList.add("toast-card", "toast-hidden")

    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        this.element.classList.remove("toast-hidden")
        this.element.classList.add("toast-visible")
      })
    })

    this.timeout = setTimeout(() => this.dismiss(), 4000)

    this.element.addEventListener("mouseenter", this.#pause)
    this.element.addEventListener("mouseleave", this.#resume)
    this.element.addEventListener("focusin", this.#pause)
    this.element.addEventListener("focusout", this.#resume)
  }

  disconnect() {
    clearTimeout(this.timeout)
    this.element.removeEventListener("mouseenter", this.#pause)
    this.element.removeEventListener("mouseleave", this.#resume)
    this.element.removeEventListener("focusin", this.#pause)
    this.element.removeEventListener("focusout", this.#resume)
  }

  dismiss() {
    clearTimeout(this.timeout)

    this.element.classList.remove("toast-visible")
    this.element.classList.add("toast-hidden")

    // Keep the Turbo Frame in the DOM — only remove this flash node so a
    // surrounding <turbo-frame> stays usable for later stream updates.
    setTimeout(() => this.element.remove(), 200)
  }

  #pause = () => {
    clearTimeout(this.timeout)
  }

  #resume = () => {
    this.timeout = setTimeout(() => this.dismiss(), 2000)
  }
}
