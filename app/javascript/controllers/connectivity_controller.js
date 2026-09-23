import { Controller } from "@hotwired/stimulus"
import { openDB, SCOUTING_STORE, PIT_STORE } from "lib/lighthouse_db"
import { showToast } from "lib/toast"

/**
 * Manages the offline connectivity toast, sync queue count,
 * progress reporting, and failed entry details.
 */
export default class extends Controller {
  static targets = [
    "banner", "status", "queueCount",
    "progress", "progressBar", "progressText",
    "details", "detailsList"
  ]

  connect() {
    this._onOnline = () => this.#goOnline()
    this._onOffline = () => this.#goOffline()
    this._onMessage = (event) => this.#handleSwMessage(event)
    this._onSyncComplete = () => this.#updateQueueCount()
    this._onEntryQueued = () => this.#updateQueueCount()

    window.addEventListener("online", this._onOnline)
    window.addEventListener("offline", this._onOffline)
    window.addEventListener("lighthouse:sync-complete", this._onSyncComplete)
    window.addEventListener("lighthouse:entry-queued", this._onEntryQueued)
    // Single toast owner: other controllers (offline, sortable, scouting)
    // dispatch lighthouse:toast instead of creating their own fixed banners,
    // so offline + sync toasts never stack as duplicates.
    this._onToast = (event) => {
      const { message, type } = event.detail || {}
      if (message) showToast(message, { type: type || "info" })
    }
    window.addEventListener("lighthouse:toast", this._onToast)
    navigator.serviceWorker?.addEventListener("message", this._onMessage)

    if (navigator.onLine) {
      this.#goOnline()
    } else {
      this.#goOffline()
    }

    this.#updateQueueCount()
  }

  disconnect() {
    window.removeEventListener("online", this._onOnline)
    window.removeEventListener("offline", this._onOffline)
    window.removeEventListener("lighthouse:sync-complete", this._onSyncComplete)
    window.removeEventListener("lighthouse:entry-queued", this._onEntryQueued)
    window.removeEventListener("lighthouse:toast", this._onToast)
    navigator.serviceWorker?.removeEventListener("message", this._onMessage)
    if (this._autoDismissTimeout) clearTimeout(this._autoDismissTimeout)
    if (this._prefetchBannerTimeout) clearTimeout(this._prefetchBannerTimeout)
  }

  // --- Actions ---

  async retrySync() {
    if (!navigator.onLine) return

    this.#showSyncing()

    try {
      const reg = await navigator.serviceWorker?.ready
      if (reg?.sync) {
        await reg.sync.register("sync-scouting-entries")
        await reg.sync.register("sync-pit-scouting-entries")
      }
    } catch {
      // Background sync not available
    }

    setTimeout(() => this.#updateQueueCount(), 3000)
  }

  toggleDetails(event) {
    if (this.hasDetailsTarget) {
      this.detailsTarget.classList.toggle("hidden")
      const expanded = !this.detailsTarget.classList.contains("hidden")
      event?.currentTarget?.setAttribute("aria-expanded", String(expanded))
      if (expanded) {
        this.#populateDetails()
      }
    }
  }

  async clearFailed() {
    try {
      const db = await openDB()

      try {
        for (const storeName of [SCOUTING_STORE, PIT_STORE]) {
          if (!db.objectStoreNames.contains(storeName)) continue

          const tx = db.transaction(storeName, "readwrite")
          const store = tx.objectStore(storeName)

          const entries = await new Promise((resolve, reject) => {
            const req = store.getAll()
            req.onsuccess = () => resolve(req.result)
            req.onerror = () => reject(req.error)
          })

          for (const entry of entries) {
            if (entry._syncFailed) {
              store.delete(entry.client_uuid)
            }
          }

          await new Promise((resolve, reject) => {
            tx.oncomplete = resolve
            tx.onerror = () => reject(tx.error)
          })
        }
      } finally {
        db.close()
      }

      this.#updateQueueCount()

      if (this.hasDetailsTarget) {
        this.#populateDetails()
      }
    } catch (error) {
      console.error("[Lighthouse] Failed to clear failed entries:", error)
    }
  }

  // --- Private ---

  #showBanner() {
    if (!this.hasBannerTarget) return
    const el = this.bannerTarget
    el.classList.remove("hidden")
    el.style.opacity = "0"
    el.style.transform = "translateX(-1rem)"
    el.style.transition = "opacity 0.2s ease-out, transform 0.2s ease-out"

    requestAnimationFrame(() => {
      el.style.opacity = "1"
      el.style.transform = "translateX(0)"
    })
  }

  #hideBanner() {
    if (!this.hasBannerTarget) return
    const el = this.bannerTarget

    el.style.transition = "opacity 0.2s ease-out, transform 0.2s ease-out"
    el.style.opacity = "0"
    el.style.transform = "translateX(-1rem)"

    setTimeout(() => {
      el.classList.add("hidden")
      el.style.opacity = ""
      el.style.transform = ""
      if (this.hasDetailsTarget) {
        this.detailsTarget.classList.add("hidden")
      }
    }, 200)
  }

  #autoDismissAfter(ms) {
    if (this._autoDismissTimeout) clearTimeout(this._autoDismissTimeout)
    this._autoDismissTimeout = setTimeout(() => {
      this._autoDismissTimeout = null
      this.#updateQueueCount()
    }, ms)
  }

  #goOnline() {
    this.#hideProgress()
    this.#updateQueueCount()
  }

  #goOffline() {
    this.#showBanner()
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = "You are offline"
    }
    this.#hideProgress()
  }

  #showSyncing() {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = "Syncing..."
    }
    if (this.hasProgressTarget) {
      this.progressTarget.classList.remove("hidden")
    }
    if (this.hasProgressBarTarget) {
      this.progressBarTarget.style.width = "0%"
      // aria-valuenow lives on the role=progressbar wrapper (layout ERB);
      // keep the fill + wrapper in sync for AT.
      this.progressBarTarget.setAttribute("aria-valuenow", "0")
      this.progressBarTarget.closest("[role='progressbar']")?.setAttribute("aria-valuenow", "0")
    }
  }

  #hideProgress() {
    if (this.hasProgressTarget) {
      this.progressTarget.classList.add("hidden")
    }
  }

  #handleSwMessage(event) {
    const data = event.data
    if (!data) return

    if (data.type === "sync-progress") {
      this.#handleSyncProgress(data)
    } else if (data.type === "sync-complete") {
      this.#handleSyncComplete(data)
    } else if (data.type === "prefetch-progress") {
      this.#handlePrefetchProgress(data)
    } else if (data.type === "prefetch-complete") {
      this.#handlePrefetchComplete(data)
    }
  }

  #handleSyncProgress(data) {
    if (data.phase === "start") {
      this.#showBanner()
      this.#showSyncing()
      if (this.hasProgressTextTarget) {
        this.progressTextTarget.textContent = `Syncing ${data.total} ${data.total === 1 ? "entry" : "entries"}...`
      }
    } else if (data.phase === "error") {
      if (this.hasStatusTarget) {
        this.statusTarget.textContent = "Sync error"
      }
      this.#hideProgress()
      this.#updateQueueCount()
    }
  }

  #handleSyncComplete(data) {
    this.#hideProgress()

    if (data.synced > 0 || data.failed > 0) {
      const storeName = data.store === SCOUTING_STORE ? "match" : "pit"

      if (this.hasStatusTarget) {
        if (data.failed > 0) {
          this.statusTarget.textContent = `${data.synced} ${storeName} synced, ${data.failed} failed`
        } else {
          this.statusTarget.textContent = `${data.synced} ${storeName} ${data.synced === 1 ? "entry" : "entries"} synced`
        }
      }
    }

    this._lastSyncResult = {
      ...this._lastSyncResult,
      [data.store]: { synced: data.synced, failed: data.failed, total: data.total, at: new Date().toISOString() }
    }

    this.#updateQueueCount()
  }

  async #updateQueueCount() {
    try {
      const db = await openDB()
      let total = 0
      let pendingCount = 0
      let failedCount = 0

      try {
        for (const storeName of [SCOUTING_STORE, PIT_STORE]) {
          if (!db.objectStoreNames.contains(storeName)) continue

          const entries = await new Promise((resolve, reject) => {
            const tx = db.transaction(storeName, "readonly")
            const req = tx.objectStore(storeName).getAll()
            req.onsuccess = () => resolve(req.result)
            req.onerror = () => reject(req.error)
          })

          for (const entry of entries) {
            total++
            if (entry._syncFailed) {
              failedCount++
            } else {
              pendingCount++
            }
          }
        }
      } finally {
        db.close()
      }

      if (this.hasQueueCountTarget) {
        if (total > 0) {
          let text = `${pendingCount} pending`
          if (failedCount > 0) {
            text += `, ${failedCount} failed`
          }
          this.queueCountTarget.textContent = text
          this.queueCountTarget.classList.remove("hidden")
        } else {
          this.queueCountTarget.classList.add("hidden")
        }
      }

      // Show/hide based on queue state
      if (total > 0 && navigator.onLine) {
        this.#showBanner()
        if (this.hasStatusTarget && !this.statusTarget.textContent.includes("Syncing")) {
          if (failedCount > 0 && pendingCount === 0) {
            this.statusTarget.textContent = `${failedCount} failed ${failedCount === 1 ? "entry" : "entries"}`
          } else {
            this.statusTarget.textContent = "Entries queued for sync"
          }
        }
      } else if (total === 0 && navigator.onLine) {
        this.#hideBanner()
      }
    } catch {
      // IndexedDB not available
    }
  }

  async #populateDetails() {
    if (!this.hasDetailsListTarget) return

    try {
      const db = await openDB()
      const items = []

      try {
        for (const storeName of [SCOUTING_STORE, PIT_STORE]) {
          if (!db.objectStoreNames.contains(storeName)) continue

          const entries = await new Promise((resolve, reject) => {
            const tx = db.transaction(storeName, "readonly")
            const req = tx.objectStore(storeName).getAll()
            req.onsuccess = () => resolve(req.result)
            req.onerror = () => reject(req.error)
          })

          const type = storeName === SCOUTING_STORE ? "Match" : "Pit"

          for (const entry of entries) {
            items.push({
              type,
              uuid: entry.client_uuid,
              team: entry.frc_team_id || "?",
              createdAt: entry.created_at,
              failed: entry._syncFailed || false,
              errors: entry._syncErrors || []
            })
          }
        }
      } finally {
        db.close()
      }

      if (items.length === 0) {
        this.detailsListTarget.replaceChildren()
        const empty = document.createElement("li")
        empty.className = "text-xs text-gray-400 py-1.5 text-center"
        empty.textContent = "No queued entries"
        this.detailsListTarget.appendChild(empty)
        return
      }

      // Build rows with textContent only: team ids, timestamps, and sync
      // errors all originate from IndexedDB / server responses and must
      // never be interpolated into innerHTML.
      this.detailsListTarget.replaceChildren()
      for (const item of items) {
        const row = document.createElement("li")
        row.className = "flex items-center justify-between py-1.5 border-b border-gray-800/50 last:border-0"

        const info = document.createElement("div")
        info.className = "min-w-0"

        const type = document.createElement("span")
        type.className = "text-xs font-medium text-gray-300"
        type.textContent = item.type
        info.appendChild(type)

        const team = document.createElement("span")
        team.className = "text-xs text-gray-400 ml-1"
        team.textContent = `Team ${item.team}`
        info.appendChild(team)

        const time = document.createElement("span")
        time.className = "text-[10px] text-gray-400 ml-1"
        time.textContent = item.createdAt ? new Date(item.createdAt).toLocaleTimeString() : ""
        info.appendChild(time)

        if (item.errors.length > 0) {
          const errorMsg = document.createElement("div")
          errorMsg.className = "text-[10px] text-red-400/70 mt-0.5"
          errorMsg.textContent = item.errors[0]
          info.appendChild(errorMsg)
        }

        const status = document.createElement("span")
        status.className = `text-[10px] font-medium shrink-0 ml-2 ${item.failed ? "text-red-400" : "text-amber-400"}`
        status.textContent = item.failed ? "Failed" : "Pending"
        // Text label (not color-only) for AT + sighted users alike.
        status.setAttribute("aria-label", `Sync status: ${item.failed ? "Failed" : "Pending"}`)

        row.append(info, status)
        this.detailsListTarget.appendChild(row)
      }
    } catch (error) {
      console.error("[Lighthouse] Failed to populate details:", error)
    }
  }

  #handlePrefetchProgress(_data) {
    // Silenced — prefetch runs in the background without showing the banner.
  }

  #handlePrefetchComplete(_data) {
    // Silenced — prefetch completion does not show a notification.
  }
}
