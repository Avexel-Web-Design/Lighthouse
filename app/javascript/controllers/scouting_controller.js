import { Controller } from "@hotwired/stimulus"
import { openDB, SCOUTING_STORE } from "lib/lighthouse_db"
import { showToast } from "lib/toast"
import { moveRadioSelection, switchPillTab, updateSelectionCards } from "lib/selection"

// Scoring constants matching app/models/concerns/scoring.rb
const FUEL_POINT_VALUE = 1
const AUTON_CLIMB_POINTS = 15
const CLIMB_POINTS = { None: 0, L1: 10, L2: 20, L3: 30 }
const HOLD_REPEAT_DELAY = 250
const HOLD_REPEAT_INTERVAL = 75

export default class extends Controller {
  static targets = [
    "autonMade", "autonMissed",
    "teleopMade", "teleopMissed",
    "autonClimb", "endgameClimb",
    "summaryAccuracy",
    "totalPoints", "totalMade", "totalMissed",
    "dataField", "tabContent",
    "matchSelect", "teamSelect"
  ]

  static values = {
    autonMade:    { type: Number, default: 0 },
    autonMissed:  { type: Number, default: 0 },
    teleopMade:   { type: Number, default: 0 },
    teleopMissed: { type: Number, default: 0 },
    autonClimb:   { type: Boolean, default: false },
    endgameClimb: { type: String, default: "None" },
    defenseRating:{ type: Number, default: 0 },
    matchTeams:   { type: Object, default: {} }
  }

  connect() {
    this.updateDisplay()
    this.#initializeToggleState()
    this.#initializeTeamFilter()
    this.#initializeMatchFilter()
    this.#cacheReferenceData()
    this._holdTimeout = null
    this._holdInterval = null
    this._holdTarget = null
    this._suppressedClick = null

    this._onKeydown = (event) => this.#handleKeydown(event)
    document.addEventListener("keydown", this._onKeydown)
  }

  disconnect() {
    this.#stopCounterHold()
    document.removeEventListener("keydown", this._onKeydown)
  }

  // --- Counter actions ---

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

  // --- Climb actions ---

  toggleAutonClimb() {
    this.autonClimbValue = !this.autonClimbValue
    this.#updateToggleVisual()
    this.updateDisplay()
  }

  // Keyboard support for the auton-climb switch (role="switch"):
  // Space/Enter toggle, matching native checkbox behavior.
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
      ["bg-gray-800", "border-gray-700"])

    this.updateDisplay()
  }

  selectDefense(event) {
    const rating = parseInt(event.currentTarget.dataset.rating, 10)
    this.defenseRatingValue = rating

    updateSelectionCards(this.element, "[data-defense-card]",
      (card) => parseInt(card.dataset.rating, 10) === rating,
      ["bg-gray-800", "border-gray-700"])
  }

  // Arrow-key navigation within climb/defense radiogroups (WAI-APG).
  navigateRadio(event) {
    const group = event.currentTarget.closest("[role='radiogroup']")
    if (!group) return
    const cards = [...group.querySelectorAll("[role='radio']")]
    moveRadioSelection(event, cards, cards.indexOf(event.currentTarget))
  }

  // --- Tab switching ---

  navigateTab(event) {
    const buttons = [...this.element.querySelectorAll("[data-tab-button]")]
    moveRadioSelection(event, buttons, buttons.indexOf(event.currentTarget))
  }

  switchTab(event) {
    const tab = event.currentTarget.dataset.tab
    const buttons = [...this.element.querySelectorAll("[data-tab-button]")]
    switchPillTab(this.element, buttons, this.tabContentTargets, tab)
  }

  // --- Match-team filtering ---

  matchChanged() {
    this.#filterTeams()
  }

  teamChanged() {
    this.#filterMatches()
  }

  // --- Form submission ---

  submitForm(event) {
    const payload = this.#buildDataPayload()

    if (this.hasDataFieldTarget) {
      this.dataFieldTarget.value = JSON.stringify(payload)
    }

    // If offline, save to IndexedDB queue and prevent server submission
    if (!navigator.onLine) {
      event.preventDefault()
      this.#saveToOfflineQueue(payload)
    }
  }

  // --- Private helpers ---

  updateDisplay() {
    const made = this.autonMadeValue + this.teleopMadeValue
    const missed = this.autonMissedValue + this.teleopMissedValue
    const total = made + missed
    const accuracy = total > 0 ? ((made / total) * 100).toFixed(1) : "0.0"

    let points = made * FUEL_POINT_VALUE
    if (this.autonClimbValue) points += AUTON_CLIMB_POINTS
    points += CLIMB_POINTS[this.endgameClimbValue] || 0

    // Update phase counters
    this.#setTargetText("autonMade", this.autonMadeValue)
    this.#setTargetText("autonMissed", this.autonMissedValue)
    this.#setTargetText("teleopMade", this.teleopMadeValue)
    this.#setTargetText("teleopMissed", this.teleopMissedValue)

    // Update totals
    this.#setTargetText("totalMade", made)
    this.#setTargetText("totalMissed", missed)
    this.#setTargetText("totalPoints", points)

    // Update accuracy display
    this.#setTargetText("summaryAccuracy", `${accuracy}%`)
  }

  #buildDataPayload() {
    // Read the auton_path from the field-map controller's hidden field
    const pathField = this.element.querySelector("[data-auton-path-field]")
    let autonPath = []
    try {
      autonPath = pathField ? JSON.parse(pathField.value) : []
    } catch { /* empty */ }

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

  async #saveToOfflineQueue(payload) {
    try {
      const db = await openDB()
      const form = this.element.closest("form")

      const entry = {
        client_uuid: crypto.randomUUID(),
        match_id: form?.querySelector("[name*='match_id']")?.value || null,
        frc_team_id: form?.querySelector("[name*='frc_team_id']")?.value || null,
        event_id: form?.querySelector("[name*='event_id']")?.value || null,
        notes: form?.querySelector("[name*='notes']")?.value || "",
        data: payload,
        created_at: new Date().toISOString()
      }

      const tx = db.transaction(SCOUTING_STORE, "readwrite")
      tx.objectStore(SCOUTING_STORE).add(entry)
      await new Promise((resolve, reject) => {
        tx.oncomplete = resolve
        tx.onerror = () => reject(tx.error)
      })

      db.close()

      // Notify the user and update the connectivity banner
      this.#showOfflineConfirmation()
      window.dispatchEvent(new CustomEvent("lighthouse:entry-queued"))
    } catch (error) {
      console.error("[Lighthouse] Failed to save offline entry:", error)
      alert("Failed to save entry offline. Please try again.")
    }
  }

  async #cacheReferenceData() {
    // Cache match/team dropdown data in IndexedDB for offline form hydration
    if (!navigator.onLine) return
    try {
      const form = this.element.closest("form")
      const eventId = form?.querySelector("[name*='event_id']")?.value
      if (!eventId) return

      // Collect team options from the current dropdown
      const teams = this._allTeamOptions?.filter(o => o.value !== "").map(o => ({
        value: o.value,
        text: o.text
      })) || []

      // matchTeams is already a Stimulus value
      const matchTeams = this.matchTeamsValue || {}

      // Collect match options from the match dropdown
      const matches = this.hasMatchSelectTarget
        ? Array.from(this.matchSelectTarget.options).filter(o => o.value !== "").map(o => ({
            value: o.value,
            text: o.text
          }))
        : []

      const db = await openDB()
      const tx = db.transaction("event_data", "readwrite")
      tx.objectStore("event_data").put({
        event_id: eventId,
        teams,
        matches,
        match_teams: matchTeams,
        cached_at: new Date().toISOString()
      })
      await new Promise((resolve, reject) => {
        tx.oncomplete = resolve
        tx.onerror = () => reject(tx.error)
      })
      db.close()
    } catch (error) {
      console.warn("[Lighthouse] Failed to cache reference data:", error)
    }
  }

  #showOfflineConfirmation() {
    // Rendered via the shared toast helper (textContent-only, role=status)
    // into the connectivity-owned #toast-stack — no duplicate banners.
    showToast("Entry saved offline. It will sync when you reconnect.", { type: "info" })
  }

  #handleKeydown(event) {
    // Ignore when typing in inputs, textareas, or selects
    const tag = event.target.tagName
    if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT") return
    if (event.target.isContentEditable) return

    // Ignore if any modifier key is held
    if (event.metaKey || event.ctrlKey || event.altKey) return

    const key = event.key.toLowerCase()
    const phase = this.#activePhase()
    if (!phase) return

    switch (key) {
      case "q":
      case "w":
        this.#incrementValue(phase, "Made")
        this.updateDisplay()
        break
      case "e":
      case "r":
        this.#incrementValue(phase, "Missed")
        this.updateDisplay()
        break
      case "a":
      case "s":
        this.#decrementValue(phase, "Made")
        this.updateDisplay()
        break
      case "d":
      case "f":
        this.#decrementValue(phase, "Missed")
        this.updateDisplay()
        break
      default:
        return
    }

    event.preventDefault()
  }

  #activePhase() {
    const activeTab = this.element.querySelector("[data-tab-button][aria-selected='true']")
    return activeTab?.dataset.tab || "auton"
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
    const capitalizedName = name.charAt(0).toUpperCase() + name.slice(1)
    if (this[`has${capitalizedName}Target`]) {
      const target = this[`${name}Target`]
      target.textContent = value
    }
  }

  #initializeToggleState() {
    if (this.autonClimbValue) {
      this.#updateToggleVisual()
    }
  }

  #updateToggleVisual() {
    if (!this.hasAutonClimbTarget) return

    const target = this.autonClimbTarget
    const track = target.querySelector("[data-toggle-track]")
    const knob = target.querySelector("[data-toggle-knob]")

    // Update ARIA
    target.setAttribute("aria-checked", this.autonClimbValue)

    if (this.autonClimbValue) {
      target.classList.add("ring-2", "ring-orange-400", "bg-orange-900/50")
      if (track) track.classList.replace("bg-gray-700", "bg-orange-500")
      if (knob) {
        knob.style.left = "auto"
        knob.style.right = "4px"
      }
    } else {
      target.classList.remove("ring-2", "ring-orange-400", "bg-orange-900/50")
      if (track) track.classList.replace("bg-orange-500", "bg-gray-700")
      if (knob) {
        knob.style.left = "4px"
        knob.style.right = "auto"
      }
    }
  }

  #initializeTeamFilter() {
    if (!this.hasMatchSelectTarget || !this.hasTeamSelectTarget) return

    // Cache all original team options so we can restore them
    this._allTeamOptions = Array.from(this.teamSelectTarget.options).map(opt => ({
      value: opt.value,
      text: opt.text
    }))

    // If a match is already selected (e.g. editing an entry), filter now
    if (this.matchSelectTarget.value) {
      this.#filterTeams()
    }
  }

  #filterTeams() {
    if (!this.hasMatchSelectTarget || !this.hasTeamSelectTarget) return

    const select = this.teamSelectTarget
    const matchId = this.matchSelectTarget.value
    const currentTeamId = select.value

    // Clear existing options
    select.replaceChildren()

    // Always add the prompt option
    const prompt = document.createElement("option")
    prompt.value = ""
    prompt.textContent = "Select team..."
    select.appendChild(prompt)

    if (!matchId) {
      // No match selected: restore all teams
      this._allTeamOptions.forEach(opt => {
        if (opt.value === "") return // skip original prompt
        const option = document.createElement("option")
        option.value = opt.value
        option.textContent = opt.text
        select.appendChild(option)
      })
    } else {
      // Match selected: show only teams in this match, grouped by alliance
      const teams = this.matchTeamsValue[matchId] || []

      const redTeams = teams.filter(t => t.color === "red")
      const blueTeams = teams.filter(t => t.color === "blue")

      if (redTeams.length > 0) {
        const redGroup = document.createElement("optgroup")
        redGroup.label = "Red Alliance"
        redTeams.forEach(t => {
          const option = document.createElement("option")
          option.value = t.id
          option.textContent = `${t.number} - ${t.name}`
          redGroup.appendChild(option)
        })
        select.appendChild(redGroup)
      }

      if (blueTeams.length > 0) {
        const blueGroup = document.createElement("optgroup")
        blueGroup.label = "Blue Alliance"
        blueTeams.forEach(t => {
          const option = document.createElement("option")
          option.value = t.id
          option.textContent = `${t.number} - ${t.name}`
          blueGroup.appendChild(option)
        })
        select.appendChild(blueGroup)
      }
    }

    // Restore previous selection if it's still a valid option
    const validValues = new Set(Array.from(select.options).map(o => o.value))
    if (validValues.has(currentTeamId)) {
      select.value = currentTeamId
    } else {
      select.value = ""
    }
  }

  #initializeMatchFilter() {
    if (!this.hasMatchSelectTarget || !this.hasTeamSelectTarget) return

    // Cache all original match options so we can restore them
    this._allMatchOptions = Array.from(this.matchSelectTarget.options).map(opt => ({
      value: opt.value,
      text: opt.text
    }))

    // Build reverse lookup: team_id (string) → Set of match_id strings
    this._teamMatchIds = {}
    const matchTeams = this.matchTeamsValue || {}
    for (const [matchId, teams] of Object.entries(matchTeams)) {
      for (const team of teams) {
        const teamId = String(team.id)
        if (!this._teamMatchIds[teamId]) {
          this._teamMatchIds[teamId] = new Set()
        }
        this._teamMatchIds[teamId].add(matchId)
      }
    }

    // If a team is already pre-filled (e.g. from "Scout This Team" link), filter now
    if (this.teamSelectTarget.value && !this.matchSelectTarget.value) {
      this.#filterMatches()
    }
  }

  #filterMatches() {
    if (!this.hasMatchSelectTarget || !this.hasTeamSelectTarget) return

    const select = this.matchSelectTarget
    const teamId = this.teamSelectTarget.value
    const previousMatchId = select.value

    // Clear existing options
    select.replaceChildren()

    // Always add the prompt option
    const prompt = document.createElement("option")
    prompt.value = ""
    prompt.textContent = "Select match..."
    select.appendChild(prompt)

    if (!teamId) {
      // No team selected: restore all matches
      this._allMatchOptions.forEach(opt => {
        if (opt.value === "") return // skip original prompt
        const option = document.createElement("option")
        option.value = opt.value
        option.textContent = opt.text
        select.appendChild(option)
      })
    } else {
      // Team selected: show only matches containing this team
      const validMatchIds = this._teamMatchIds[teamId] || new Set()
      this._allMatchOptions.forEach(opt => {
        if (opt.value === "") return // skip prompt
        if (validMatchIds.has(opt.value)) {
          const option = document.createElement("option")
          option.value = opt.value
          option.textContent = opt.text
          select.appendChild(option)
        }
      })
    }

    // Preserve the previous match selection if it's still in the filtered list
    const validValues = new Set(Array.from(select.options).map(o => o.value))
    if (validValues.has(previousMatchId)) {
      select.value = previousMatchId
    }
  }
}
