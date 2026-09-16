/**
 * Shared toast helper for the Lighthouse offline subsystem.
 *
 * All Stimulus controllers render toasts through here so user-controlled
 * strings (team numbers, server messages, sync errors) are always inserted
 * via textContent — never innerHTML. No dependencies, no npm packages.
 *
 * Controllers that own a visible banner (connectivity) can also listen for
 * the "lighthouse:toast" window event and render it, which keeps the
 * connectivity + offline controllers from stacking duplicate banners:
 *
 *   window.dispatchEvent(new CustomEvent("lighthouse:toast", {
 *     detail: { message: "Synced 3 entries.", type: "success" }
 *   }))
 */

const TOAST_STYLES = {
  success: "bg-orange-600 text-white",
  info: "bg-gray-900 border border-amber-500/30 text-gray-200",
  error: "bg-red-600 text-white"
}

// Static icon paths (no interpolated content — safe to clone as SVG nodes).
const TOAST_ICON_PATHS = {
  success: "M5 13l4 4L19 7",
  info: "M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z",
  error: "M6 18L18 6M6 6l12 12"
}

function buildIcon(type) {
  const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg")
  svg.setAttribute("class", "w-4 h-4 shrink-0")
  svg.setAttribute("fill", "none")
  svg.setAttribute("stroke", "currentColor")
  svg.setAttribute("viewBox", "0 0 24 24")
  svg.setAttribute("aria-hidden", "true")

  const path = document.createElementNS("http://www.w3.org/2000/svg", "path")
  path.setAttribute("stroke-linecap", "round")
  path.setAttribute("stroke-linejoin", "round")
  path.setAttribute("stroke-width", "2")
  path.setAttribute("d", TOAST_ICON_PATHS[type] || TOAST_ICON_PATHS.info)

  svg.appendChild(path)
  return svg
}

/**
 * Render a toast. Message is always set via textContent (XSS-safe).
 * Returns the toast element.
 */
export function showToast(message, { type = "info", container = null, duration = 4000 } = {}) {
  const host = container || document.getElementById("toast-stack") || document.body
  const style = TOAST_STYLES[type] || TOAST_STYLES.info

  const toast = document.createElement("div")
  toast.className = `toast-card ${style}`
  // Errors interrupt; info/success are polite so screen readers announce them.
  toast.setAttribute("role", type === "error" ? "alert" : "status")
  toast.setAttribute("aria-live", type === "error" ? "assertive" : "polite")

  toast.appendChild(buildIcon(type))

  const text = document.createElement("span")
  text.className = "flex-1"
  text.textContent = message
  toast.appendChild(text)

  host.appendChild(toast)

  requestAnimationFrame(() => {
    toast.classList.add("toast-visible")
  })

  window.setTimeout(() => {
    toast.classList.remove("toast-visible")
    window.setTimeout(() => toast.remove(), 250)
  }, duration)

  return toast
}
