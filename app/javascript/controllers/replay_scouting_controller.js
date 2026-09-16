import { Controller } from "@hotwired/stimulus"
import { moveRadioSelection, switchPillTab, updateSelectionCards } from "lib/selection"

const FUEL_POINT_VALUE = 1
const AUTON_CLIMB_POINTS = 15
const CLIMB_POINTS = { None: 0, L1: 10, L2: 20, L3: 30 }
const HOLD_REPEAT_DELAY = 250
const HOLD_REPEAT_INTERVAL = 75

export default class extends Controller {
  static targets = [
    "autonMade", "autonMissed",
    "teleopMade", "teleopMissed",
    "autonClimb",
    "summaryAccuracy",
    "totalPoints", "totalMade", "totalMissed",
    "dataField", "tabContent", "questionPanel",
    "teamSelect", "teamField", "teamCard", "teamRequiredState", "teamFormState"
  ]

  static values = {
    autonMade: { type: Number, default: 0 },
    autonMissed: { type: Number, default: 0 },
    teleopMade: { type: Number, default: 0 },
    teleopMissed: { type: Number, default: 0 },
    autonClimb: { type: Boolean, default: false },
    endgameClimb: { type: String, default: "None" },
    defenseRating: { type: Number, default: 0 }
  }

  connect() {
    this.updateDisplay()
    this.#updateToggleVisual()
    this.#syncSelectedTeam()
    this._holdTimeout = null
    this._holdInterval = null
    this._holdTarget = null
    this._suppressedClick = null
  }

  disconnect() {
    this.#stopCounterHold()
  }

  incrementMade(event) {
    const phase = event.currentTarget.dataset.phase
    this.#incrementValue(phase, "Made")
    this.updateDisplay()
  }

  incrementMissed(event) {
    const phase = event.currentTarget.dataset.phase
    this.#incrementValue(phase, "Missed")
    this.updateDisplay()
  }

  undoMade(event) {
    const phase = event.currentTarget.dataset.phase
    this.#decrementValue(phase, "Made")
    this.updateDisplay()
  }

  undoMissed(event) {
    const phase = event.currentTarget.dataset.phase
    this.#decrementValue(phase, "Missed")
    this.updateDisplay()
  }

  handleCounterClick(event) {
    if (this.#shouldSuppressClick(event)) return

    this.#applyCounterAction(event.currentTarget)
  }

  startCounterHold(event) {
    if (event.pointerType === "mouse" && event.button !== 0) return

    const target = event.currentTarget
    event.preventDefault()

    this.#stopCounterHold()
    this.#applyCounterAction(target)

    this._holdTarget = target
    this._suppressedClick = {
      target,
      expiresAt: Date.now() + 500
    }

    if (typeof target.setPointerCapture === "function") {
      try {
        target.setPointerCapture(event.pointerId)
      } catch {
        // Ignore browsers that reject pointer capture for this interaction.
      }
    }

    this._holdTimeout = window.setTimeout(() => {
      this._holdInterval = window.setInterval(() => {
        this.#applyCounterAction(target)
      }, HOLD_REPEAT_INTERVAL)
    }, HOLD_REPEAT_DELAY)
  }

  stopCounterHold(event) {
    if (event && this._holdTarget && event.currentTarget !== this._holdTarget) return

    this.#stopCounterHold()
  }

  switchTab(event) {
    const tab = event.currentTarget.dataset.tab
    const buttons = [...this.element.querySelectorAll("[data-tab-button]")]
    switchPillTab(this.element, buttons, this.tabContentTargets, tab)
  }

  showQuestions() {
    this.questionPanelTarget.scrollIntoView({ behavior: "smooth", block: "start" })
  }

  showOverlay() {
    this.element.scrollIntoView({ behavior: "smooth", block: "start" })
  }

  selectTeam(event) {
    event.preventDefault()
    this.#setSelectedTeam(event.currentTarget.dataset.teamId)
  }

  selectTeamFromDropdown(event) {
    this.#setSelectedTeam(event.currentTarget.value)
  }

  toggleAutonClimb() {
    this.autonClimbValue = !this.autonClimbValue
    this.#updateToggleVisual()
    this.updateDisplay()
  }

  toggleAutonClimbFromKey(event) {
    if (event.key === " " || event.key === "Enter") {
      event.preventDefault()
      this.toggleAutonClimb()
    }
  }

  selectClimb(event) {
    const level = event.currentTarget.dataset.level
    this.endgameClimbValue = level

    updateSelectionCards(this.element, "[data-climb-card]",
      (card) => card.dataset.level === level,
      ["bg-gray-900", "border-gray-800"])

    this.updateDisplay()
  }

  selectDefense(event) {
    const rating = parseInt(event.currentTarget.dataset.rating, 10)
    this.defenseRatingValue = rating

    updateSelectionCards(this.element, "[data-defense-card]",
      (card) => parseInt(card.dataset.rating, 10) === rating,
      ["bg-gray-900", "border-gray-800"])
  }

  navigateRadio(event) {
    const group = event.currentTarget.closest("[role='radiogroup']")
    if (!group) return
    const cards = [...group.querySelectorAll("[role='radio']")]
    moveRadioSelection(event, cards, cards.indexOf(event.currentTarget))
  }

  submitForm() {
    if (this.hasDataFieldTarget) {
      this.dataFieldTarget.value = JSON.stringify(this.#buildDataPayload())
    }
  }

  updateDisplay() {
    const made = this.autonMadeValue + this.teleopMadeValue
    const missed = this.autonMissedValue + this.teleopMissedValue
    const total = made + missed
    const accuracy = total > 0 ? ((made / total) * 100).toFixed(1) : "0.0"

    let points = made * FUEL_POINT_VALUE
    if (this.autonClimbValue) points += AUTON_CLIMB_POINTS
    points += CLIMB_POINTS[this.endgameClimbValue] || 0

    this.#setTargetText("autonMade", this.autonMadeValue)
    this.#setTargetText("autonMissed", this.autonMissedValue)
    this.#setTargetText("teleopMade", this.teleopMadeValue)
    this.#setTargetText("teleopMissed", this.teleopMissedValue)
    this.#setTargetText("totalMade", made)
    this.#setTargetText("totalMissed", missed)
    this.#setTargetText("summaryAccuracy", `${accuracy}%`)
    this.#setTargetText("totalPoints", points)
  }

  #buildDataPayload() {
    const pathField = this.element.querySelector("[data-auton-path-field]")
    let autonPath = []
    try {
      autonPath = pathField ? JSON.parse(pathField.value) : []
    } catch {
      autonPath = []
    }

    return {
      auton_fuel_made: this.autonMadeValue,
      auton_fuel_missed: this.autonMissedValue,
      teleop_fuel_made: this.teleopMadeValue,
      teleop_fuel_missed: this.teleopMissedValue,
      endgame_fuel_made: 0,
      endgame_fuel_missed: 0,
      auton_climb: this.autonClimbValue,
      endgame_climb: this.endgameClimbValue,
      defense_rating: this.defenseRatingValue,
      auton_path: autonPath
    }
  }

  #applyCounterAction(target) {
    const phase = target.dataset.phase
    const counterAction = target.dataset.counterAction

    switch (counterAction) {
      case "incrementMade":
        this.#incrementValue(phase, "Made")
        break
      case "incrementMissed":
        this.#incrementValue(phase, "Missed")
        break
      case "undoMade":
        this.#decrementValue(phase, "Made")
        break
      case "undoMissed":
        this.#decrementValue(phase, "Missed")
        break
      default:
        return
    }

    this.updateDisplay()
  }

  #shouldSuppressClick(event) {
    if (!this._suppressedClick) return false

    const { target, expiresAt } = this._suppressedClick
    const isExpired = Date.now() > expiresAt
    const isMatchingTarget = event.currentTarget === target

    if (isExpired || isMatchingTarget) {
      this._suppressedClick = null
    }

    if (!isMatchingTarget || isExpired) return false

    event.preventDefault()
    event.stopPropagation()
    return true
  }

  #stopCounterHold() {
    if (this._holdTimeout) {
      window.clearTimeout(this._holdTimeout)
      this._holdTimeout = null
    }

    if (this._holdInterval) {
      window.clearInterval(this._holdInterval)
      this._holdInterval = null
    }

    this._holdTarget = null
  }

  #incrementValue(phase, suffix) {
    const key = `${phase}${suffix}Value`
    this[key] = this[key] + 1
  }

  #decrementValue(phase, suffix) {
    const key = `${phase}${suffix}Value`
    this[key] = Math.max(0, this[key] - 1)
  }

  #setTargetText(name, value) {
    const capitalized = name.charAt(0).toUpperCase() + name.slice(1)
    if (this[`has${capitalized}Target`]) {
      this[`${name}Target`].textContent = value
    }
  }

  #updateToggleVisual() {
    if (!this.hasAutonClimbTarget) return

    const track = this.autonClimbTarget.querySelector("[data-toggle-track]")
    const knob = this.autonClimbTarget.querySelector("[data-toggle-knob]")

    this.autonClimbTarget.setAttribute("aria-checked", this.autonClimbValue)
    this.autonClimbTarget.classList.toggle("ring-2", this.autonClimbValue)
    this.autonClimbTarget.classList.toggle("ring-orange-400", this.autonClimbValue)
    this.autonClimbTarget.classList.toggle("bg-orange-900/50", this.autonClimbValue)

    if (track) {
      track.classList.toggle("bg-orange-500", this.autonClimbValue)
      track.classList.toggle("bg-gray-700", !this.autonClimbValue)
    }

    if (knob) {
      knob.style.left = this.autonClimbValue ? "auto" : "4px"
      knob.style.right = this.autonClimbValue ? "4px" : "auto"
    }
  }

  #setSelectedTeam(teamId) {
    const normalizedTeamId = `${teamId || ""}`

    if (this.hasTeamSelectTarget) {
      this.teamSelectTarget.value = normalizedTeamId
    }

    if (this.hasTeamFieldTarget) {
      this.teamFieldTarget.value = normalizedTeamId
    }

    this.teamCardTargets.forEach(card => {
      const selected = card.dataset.teamId === normalizedTeamId && normalizedTeamId !== ""
      const selectedClasses = (card.dataset.selectedClasses || "").split(" ").filter(Boolean)
      const unselectedClasses = (card.dataset.unselectedClasses || "").split(" ").filter(Boolean)
      const status = card.querySelector("[data-team-status]")

      card.dataset.replayTeamSelected = selected
      card.classList.remove(...selectedClasses, ...unselectedClasses)
      card.classList.add(...(selected ? selectedClasses : unselectedClasses))

      if (status) {
        status.textContent = selected ? status.dataset.selectedLabel : status.dataset.defaultLabel
      }
    })

    this.#toggleTeamSelectionState(normalizedTeamId !== "")
  }

  #syncSelectedTeam() {
    const teamId = this.hasTeamFieldTarget ? this.teamFieldTarget.value : this.hasTeamSelectTarget ? this.teamSelectTarget.value : ""
    this.#setSelectedTeam(teamId)
  }

  #toggleTeamSelectionState(selected) {
    if (this.hasTeamRequiredStateTarget) {
      this.teamRequiredStateTarget.classList.toggle("hidden", selected)
    }

    this.teamFormStateTargets.forEach(section => {
      section.classList.toggle("hidden", !selected)
    })
  }
}
