import { Controller } from "@hotwired/stimulus"

/**
 * Manages multiple auton path entries for pit scouting.
 * Each path has its own field-map canvas, fuel scored count, and action checkboxes.
 * All path data is serialized into a single hidden JSON field on form submit.
 *
 * Data structure per path:
 *   { strokes: [[{x,y},...]], fuel_scored: 3, actions: ["bump", "climb"] }
 */
export default class extends Controller {
  static targets = ["container", "hiddenField"]
  static values = {
    paths: { type: Array, default: [] },
    fieldImage: { type: String, default: "" }
  }

  connect() {
    this.pathCounter = 0

    // Restore existing paths from value (edit mode)
    if (this.pathsValue.length > 0) {
      this.pathsValue.forEach(pathData => this.#addPathBlock(pathData))
    }
  }

  addPath() {
    this.#addPathBlock(null)
  }

  removePath(event) {
    const block = event.currentTarget.closest("[data-auton-path-block]")
    if (block) {
      block.remove()
      this.#renumberBlocks()
      this.#syncHiddenField()
    }
  }

  // Called externally (e.g. from form submit) to ensure data is serialized
  serialize() {
    this.#syncHiddenField()
  }

  // --- Private ---

  #addPathBlock(existingData) {
    this.pathCounter++
    const index = this.pathCounter

    const block = document.createElement("div")
    block.setAttribute("data-auton-path-block", index)
    block.className = "bg-gray-800 rounded-lg p-3 space-y-3"

    const strokes = existingData?.strokes || []
    const strokesJson = JSON.stringify(strokes)
    const fuelScored = Number(existingData?.fuel_scored) || 0
    const actions = Array.isArray(existingData?.actions) ? existingData.actions : []

    // Built with createElement/textContent only (no innerHTML): strokes JSON
    // and action labels originate from stored form data and must never be
    // parsed as HTML. Values are assigned via properties (.value, .checked).
    block.appendChild(this.#buildPathHeader(index))
    block.appendChild(this.#buildFieldMap(strokesJson))
    block.appendChild(this.#buildFuelField(fuelScored))
    block.appendChild(this.#buildActionsField(actions))

    this.containerTarget.appendChild(block)
  }

  #buildPathHeader(index) {
    const header = document.createElement("div")
    header.className = "flex items-center justify-between mb-1"

    const label = document.createElement("span")
    label.className = "text-xs text-gray-400 font-medium"
    label.setAttribute("data-path-label", "")
    label.textContent = `Auto Path #${index}`
    header.appendChild(label)

    const remove = document.createElement("button")
    remove.type = "button"
    remove.className = "text-xs text-red-400 hover:text-red-300 transition"
    remove.setAttribute("data-action", "click->auton-paths#removePath")
    remove.textContent = "Remove"
    header.appendChild(remove)

    return header
  }

  #buildFieldMap(strokesJson) {
    const scope = document.createElement("div")
    scope.setAttribute("data-controller", "field-map")
    scope.setAttribute("data-field-map-strokes-value", strokesJson)

    const frame = document.createElement("div")
    frame.className = "relative rounded-lg overflow-hidden border border-gray-700 bg-gray-800 touch-none"

    const img = document.createElement("img")
    img.src = this.fieldImageValue
    img.className = "w-full block select-none pointer-events-none"
    img.alt = "Field map"
    img.setAttribute("data-field-map-target", "image")
    frame.appendChild(img)

    const canvas = document.createElement("canvas")
    canvas.className = "absolute inset-0 w-full h-full cursor-crosshair"
    canvas.setAttribute("data-field-map-target", "canvas")
    canvas.setAttribute("tabindex", "0")
    canvas.setAttribute("role", "application")
    canvas.setAttribute("aria-label", "Autonomous path drawing canvas. Use a pointer to draw; press U to undo the last stroke, C to clear.")
    canvas.setAttribute("data-action", "pointerdown->field-map#startStroke pointermove->field-map#continueStroke pointerup->field-map#endStroke pointerleave->field-map#endStroke keydown->field-map#handleKey")
    frame.appendChild(canvas)
    scope.appendChild(frame)

    const buttons = document.createElement("div")
    buttons.className = "flex gap-2 mt-2"
    for (const action of ["undo", "clear"]) {
      const btn = document.createElement("button")
      btn.type = "button"
      btn.className = "px-3 py-1.5 text-xs font-medium rounded-lg bg-gray-700 hover:bg-gray-600 text-gray-400 hover:text-gray-300 transition select-none"
      btn.setAttribute("data-action", `click->field-map#${action}`)
      btn.textContent = action === "undo" ? "Undo" : "Clear"
      buttons.appendChild(btn)
    }
    scope.appendChild(buttons)

    const hidden = document.createElement("input")
    hidden.type = "hidden"
    hidden.setAttribute("data-field-map-target", "hiddenField")
    hidden.setAttribute("data-path-strokes", "")
    hidden.value = strokesJson
    scope.appendChild(hidden)

    return scope
  }

  #buildFuelField(fuelScored) {
    const wrap = document.createElement("div")
    wrap.className = "grid grid-cols-2 gap-3"

    const group = document.createElement("div")
    const label = document.createElement("label")
    label.className = "block text-xs text-gray-400 mb-1"
    label.textContent = "Fuel Scored"
    group.appendChild(label)

    const input = document.createElement("input")
    input.type = "number"
    input.min = "0"
    input.value = String(fuelScored)
    input.setAttribute("data-path-fuel", "")
    input.className = "w-full bg-gray-700 border border-gray-600 rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-transparent transition"
    group.appendChild(input)
    wrap.appendChild(group)

    return wrap
  }

  #buildActionsField(actions) {
    const wrap = document.createElement("div")

    const label = document.createElement("label")
    label.className = "block text-xs text-gray-400 mb-1.5"
    label.textContent = "Actions"
    wrap.appendChild(label)

    const list = document.createElement("div")
    list.className = "flex flex-wrap gap-2"
    for (const action of ["Bump", "Trench", "Outpost", "Depot", "Climb"]) {
      const item = document.createElement("label")
      item.className = "flex items-center gap-2 px-3 py-1.5 rounded-lg border cursor-pointer transition text-sm font-medium bg-gray-700 border-gray-600 text-gray-400 hover:border-gray-500 has-[:checked]:bg-amber-500/20 has-[:checked]:border-amber-500/30 has-[:checked]:text-amber-400"

      const checkbox = document.createElement("input")
      checkbox.type = "checkbox"
      checkbox.value = action
      checkbox.className = "hidden"
      checkbox.setAttribute("data-path-action", "")
      checkbox.checked = actions.includes(action)
      item.appendChild(checkbox)

      const text = document.createElement("span")
      text.textContent = action
      item.appendChild(text)

      list.appendChild(item)
    }
    wrap.appendChild(list)

    return wrap
  }

  #renumberBlocks() {
    const blocks = this.containerTarget.querySelectorAll("[data-auton-path-block]")
    blocks.forEach((block, i) => {
      const label = block.querySelector("[data-path-label]")
      if (label) label.textContent = `Auto Path #${i + 1}`
      block.setAttribute("data-auton-path-block", i + 1)
    })
    this.pathCounter = blocks.length
  }

  #syncHiddenField() {
    if (!this.hasHiddenFieldTarget) return

    const blocks = this.containerTarget.querySelectorAll("[data-auton-path-block]")
    const paths = []

    blocks.forEach(block => {
      const strokesField = block.querySelector("[data-path-strokes]")
      let strokes = []
      try {
        strokes = strokesField ? JSON.parse(strokesField.value) : []
      } catch { /* empty */ }

      const fuelField = block.querySelector("[data-path-fuel]")
      const fuelScored = fuelField ? parseInt(fuelField.value, 10) || 0 : 0

      const actionCheckboxes = block.querySelectorAll("[data-path-action]:checked")
      const actions = Array.from(actionCheckboxes).map(cb => cb.value)

      paths.push({ strokes, fuel_scored: fuelScored, actions })
    })

    this.hiddenFieldTarget.value = JSON.stringify(paths)
  }
}
