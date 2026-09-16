/**
 * Shared selection/tab helpers for scouting-style Stimulus controllers.
 *
 * scouting_controller.js, replay_scouting_controller.js, and tabs_controller.js
 * previously each hand-rolled the same "highlight selected card" and
 * "switch tab panel" loops. They now share these dependency-free helpers so
 * styling state and ARIA stay consistent.
 */

export const SELECTED_CARD_CLASSES = [
  "ring-2",
  "ring-orange-400",
  "bg-orange-500/15",
  "border-orange-500",
  "shadow-lg",
  "shadow-orange-500/10",
  "scale-[1.02]"
]

export const SELECTED_LABEL_CLASS = "text-orange-400"
export const UNSELECTED_LABEL_CLASS = "text-gray-300"

/**
 * Highlight the selected card in a radiogroup and deselect the rest.
 *
 * @param {Element} root - scope to search within
 * @param {string} cardSelector - e.g. "[data-climb-card]"
 * @param {function(Element): boolean} isSelected - predicate per card
 * @param {string[]} unselectedClasses - classes applied when NOT selected
 */
export function updateSelectionCards(root, cardSelector, isSelected, unselectedClasses) {
  root.querySelectorAll(cardSelector).forEach((card) => {
    const selected = isSelected(card)

    card.classList.toggle("ring-2", selected)
    card.classList.toggle("ring-orange-400", selected)
    card.classList.toggle("bg-orange-500/15", selected)
    card.classList.toggle("border-orange-500", selected)
    card.classList.toggle("shadow-lg", selected)
    card.classList.toggle("shadow-orange-500/10", selected)
    card.classList.toggle("scale-[1.02]", selected)

    for (const cls of unselectedClasses) {
      card.classList.toggle(cls, !selected)
    }

    const label = card.querySelector("p:first-child")
    if (label) {
      label.classList.toggle(SELECTED_LABEL_CLASS, selected)
      label.classList.toggle(UNSELECTED_LABEL_CLASS, !selected)
    }

    // WAI-APG radiogroup: aria-checked + roving tabindex (only the checked
    // radio is in the Tab order; arrows move within the group).
    card.setAttribute("aria-checked", String(selected))
    card.tabIndex = selected ? 0 : -1
  })
}

/**
 * Move focus/selection within a radiogroup with arrow keys (WAI-APG pattern).
 * Returns true when the event was handled.
 */
export function moveRadioSelection(event, cards, currentIndex) {
  const { key } = event
  let nextIndex = null

  if (key === "ArrowRight" || key === "ArrowDown") nextIndex = (currentIndex + 1) % cards.length
  if (key === "ArrowLeft" || key === "ArrowUp") nextIndex = (currentIndex - 1 + cards.length) % cards.length
  if (key === "Home") nextIndex = 0
  if (key === "End") nextIndex = cards.length - 1

  if (nextIndex === null) return false

  event.preventDefault()
  cards[nextIndex].focus()
  cards[nextIndex].click()
  return true
}

/**
 * Show the active tab panel and update pill-style tab buttons
 * (scouting + replay-scouting share this pill look).
 */
export function switchPillTab(root, tabButtons, panels, tab) {
  tabButtons.forEach((btn) => {
    const isActive = btn.dataset.tab === tab
    btn.setAttribute("aria-selected", String(isActive))
    btn.tabIndex = isActive ? 0 : -1

    btn.classList.toggle("bg-orange-500/15", isActive)
    btn.classList.toggle("text-orange-400", isActive)
    btn.classList.toggle("shadow-sm", isActive)
    btn.classList.toggle("text-gray-400", !isActive)
    btn.classList.toggle("hover:text-gray-300", !isActive)
    btn.classList.toggle("hover:bg-gray-700/50", !isActive)
  })

  panels.forEach((panel) => {
    const isVisible = panel.dataset.tabPanel === tab
    showTabPanel(panel, isVisible)
  })
}

/**
 * Show or hide a single tab panel with the shared enter animation.
 */
export function showTabPanel(panel, isVisible) {
  if (isVisible) {
    panel.classList.remove("hidden")
    panel.classList.add("tab-panel-enter")
    panel.addEventListener("animationend", () => {
      panel.classList.remove("tab-panel-enter")
    }, { once: true })
  } else {
    panel.classList.add("hidden")
    panel.classList.remove("tab-panel-enter")
  }
}

/**
 * Underline-style tabs (generic tabs_controller): orange underline for the
 * active tab, transparent border otherwise. Shares showTabPanel animation.
 */
export function switchUnderlineTab(tabButtons, activeTab) {
  tabButtons.forEach((tab) => {
    const isActive = tab === activeTab
    tab.classList.toggle("border-orange-400", isActive)
    tab.classList.toggle("text-orange-400", isActive)
    tab.classList.toggle("border-transparent", !isActive)
    tab.classList.toggle("text-gray-400", !isActive)
    tab.setAttribute("aria-selected", String(isActive))
    tab.tabIndex = isActive ? 0 : -1
  })
}
