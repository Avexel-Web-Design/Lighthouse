import { Controller } from "@hotwired/stimulus"
import { showTabPanel, switchUnderlineTab } from "lib/selection"

export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    // Show the first panel by default if none are visible
    if (this.panelTargets.length > 0 && !this.panelTargets.some(p => !p.classList.contains("hidden"))) {
      this.panelTargets[0].classList.remove("hidden")
      if (this.tabTargets.length > 0) {
        switchUnderlineTab(this.tabTargets, this.tabTargets[0])
      }
    } else {
      // Sync roving tabindex to the currently visible tab.
      const visible = this.panelTargets.find(p => !p.classList.contains("hidden"))
      const active = this.tabTargets.find(t => t.dataset.tabsPanel === visible?.id) || this.tabTargets[0]
      if (active) switchUnderlineTab(this.tabTargets, active)
    }
  }

  select(event) {
    event.preventDefault()
    const selectedTab = event.currentTarget
    const panelId = selectedTab.dataset.tabsPanel

    // Update tab styling (shared underline style + roving tabindex)
    switchUnderlineTab(this.tabTargets, selectedTab)

    // Show/hide panels with shared animation
    this.panelTargets.forEach(panel => {
      showTabPanel(panel, panel.id === panelId)
    })
  }

  // Arrow-key navigation between tabs (WAI-APG tablist pattern).
  navigate(event) {
    const currentIndex = this.tabTargets.indexOf(event.currentTarget)
    if (currentIndex === -1) return
    let nextIndex = null
    if (event.key === "ArrowRight" || event.key === "ArrowDown") {
      nextIndex = (currentIndex + 1) % this.tabTargets.length
    } else if (event.key === "ArrowLeft" || event.key === "ArrowUp") {
      nextIndex = (currentIndex - 1 + this.tabTargets.length) % this.tabTargets.length
    } else if (event.key === "Home") {
      nextIndex = 0
    } else if (event.key === "End") {
      nextIndex = this.tabTargets.length - 1
    }
    if (nextIndex === null) return
    event.preventDefault()
    this.tabTargets[nextIndex].focus()
    this.tabTargets[nextIndex].click()
  }
}
