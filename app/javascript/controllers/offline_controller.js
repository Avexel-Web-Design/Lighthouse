import { Controller } from "@hotwired/stimulus"
import { openDB, SCOUTING_STORE, PIT_STORE } from "lib/lighthouse_db"
import { showToast } from "lib/toast"

// Session-based sync endpoints (cookies sent automatically, no Bearer token needed)
const SCOUTING_SYNC_URL = "/scouting_entries/sync"
const PIT_SYNC_URL = "/pit_scouting_entries/sync"
const MAX_RETRIES = 3
const RETRY_DELAYS = [1000, 5000, 15000]

export default class extends Controller {
  connect() {
    this.boundOnline = () => this.#handleOnline()
    this.boundOffline = () => this.#handleOffline()

    window.addEventListener("online", this.boundOnline)
    window.addEventListener("offline", this.boundOffline)

    this.checkConnection()
  }

  disconnect() {
    window.removeEventListener("online", this.boundOnline)
    window.removeEventListener("offline", this.boundOffline)
  }

  checkConnection() {
    if (navigator.onLine) {
      this.#handleOnline()
    } else {
      this.#handleOffline()
    }
  }

  async syncQueue() {
    if (!navigator.onLine) return

    let totalSynced = 0
    let totalFailed = 0

    // Sync match scouting entries
    const scoutingResult = await this.#syncStore(SCOUTING_STORE, SCOUTING_SYNC_URL)
    totalSynced += scoutingResult.synced
    totalFailed += scoutingResult.failed

    // Sync pit scouting entries
    const pitResult = await this.#syncStore(PIT_STORE, PIT_SYNC_URL)
    totalSynced += pitResult.synced
    totalFailed += pitResult.failed

    if (totalSynced > 0 || totalFailed > 0) {
      this.#showSyncBanner(totalSynced, totalFailed)
    }

    // Dispatch event so connectivity controller can update counts
    window.dispatchEvent(new CustomEvent("lighthouse:sync-complete"))
  }

  // --- Private ---

  #handleOnline() {
    this.element.classList.add("hidden")
    this.syncQueue()
  }

  #handleOffline() {
    this.element.classList.remove("hidden")
  }

  async #syncStore(storeName, syncUrl) {
    const result = { synced: 0, failed: 0 }

    try {
      const db = await openDB()

      if (!db.objectStoreNames.contains(storeName)) {
        db.close()
        return result
      }

      const tx = db.transaction(storeName, "readonly")
      const store = tx.objectStore(storeName)

      const entries = await new Promise((resolve, reject) => {
        const request = store.getAll()
        request.onsuccess = () => resolve(request.result)
        request.onerror = () => reject(request.error)
      })

      db.close()

      if (entries.length === 0) return result

      // Separate entries that have already permanently failed from those to retry
      const toSync = entries.filter(e => !e._syncFailed)
      const alreadyFailed = entries.filter(e => e._syncFailed)
      result.failed += alreadyFailed.length

      if (toSync.length === 0) return result

      const response = await this.#fetchWithRetry(syncUrl, toSync)

      if (!response) {
        result.failed += toSync.length
        return result
      }

      const json = await response.json()
      const syncedUuids = []
      const failedUuids = []

      for (const r of json.results) {
        if (r.status === "created" || r.status === "existing") {
          syncedUuids.push(r.client_uuid)
        } else if (r.status === "error") {
          failedUuids.push({ uuid: r.client_uuid, errors: r.errors })
        }
      }

      // Remove successfully synced entries
      if (syncedUuids.length > 0) {
        await this.#removeSyncedEntries(storeName, syncedUuids)
      }

      // Mark permanently failed entries so they stop being retried
      if (failedUuids.length > 0) {
        await this.#markEntriesFailed(storeName, failedUuids)
      }

      result.synced = syncedUuids.length
      result.failed += failedUuids.length
    } catch (error) {
      console.error(`[Lighthouse] Sync failed for ${storeName}:`, error)
    }

    return result
  }

  async #fetchWithRetry(url, entries) {
    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content

    for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
      try {
        const headers = {
          "Content-Type": "application/json",
          "Accept": "application/json"
        }
        if (csrfToken) {
          headers["X-CSRF-Token"] = csrfToken
        }

        const response = await fetch(url, {
          method: "POST",
          headers,
          credentials: "same-origin",
          body: JSON.stringify({ entries })
        })

        if (response.ok) {
          const contentType = response.headers.get("Content-Type") || ""
          if (!contentType.includes("application/json")) {
            console.warn("[Lighthouse] Sync response is not JSON (possible auth redirect)")
            this.#showSessionExpiredBanner()
            return null
          }
          return response
        }

        // Session expired — user needs to sign in again
        if (response.status === 401) {
          console.warn("[Lighthouse] Session expired, please sign in to sync entries")
          this.#showSessionExpiredBanner()
          return null
        }

        // CSRF / authorization failure — token may be stale
        if (response.status === 403) {
          console.warn("[Lighthouse] Sync returned 403 (forbidden) — CSRF token may be stale. Please reload the page.")
          this.#showSessionExpiredBanner()
          return null
        }

        // 4xx errors are not retryable (client error)
        if (response.status >= 400 && response.status < 500) {
          console.error(`[Lighthouse] Sync returned ${response.status}, not retrying`)
          return null
        }

        // 5xx errors are retryable
        console.warn(`[Lighthouse] Sync attempt ${attempt + 1} failed: ${response.status}`)
      } catch (error) {
        console.warn(`[Lighthouse] Sync attempt ${attempt + 1} network error:`, error)
      }

      // Wait before retrying (unless this was the last attempt)
      if (attempt < MAX_RETRIES - 1) {
        await new Promise(resolve => setTimeout(resolve, RETRY_DELAYS[attempt]))
      }
    }

    console.error("[Lighthouse] All sync retries exhausted")
    return null
  }

  async #removeSyncedEntries(storeName, uuids) {
    const db = await openDB()
    const tx = db.transaction(storeName, "readwrite")
    const store = tx.objectStore(storeName)

    for (const uuid of uuids) {
      store.delete(uuid)
    }

    await new Promise((resolve, reject) => {
      tx.oncomplete = resolve
      tx.onerror = () => reject(tx.error)
    })

    db.close()
  }

  async #markEntriesFailed(storeName, failedEntries) {
    try {
      const db = await openDB()
      const tx = db.transaction(storeName, "readwrite")
      const store = tx.objectStore(storeName)

      for (const { uuid, errors } of failedEntries) {
        const getReq = store.get(uuid)
        getReq.onsuccess = () => {
          const entry = getReq.result
          if (entry) {
            entry._syncFailed = true
            entry._syncErrors = errors || ["Unknown error"]
            entry._failedAt = new Date().toISOString()
            store.put(entry)
          }
        }
      }

      await new Promise((resolve, reject) => {
        tx.oncomplete = resolve
        tx.onerror = () => reject(tx.error)
      })

      db.close()
    } catch (error) {
      console.error("[Lighthouse] Failed to mark entries as failed:", error)
    }
  }

  #showSessionExpiredBanner() {
    // Single toast owner: render into the connectivity-owned #toast-stack via
    // the shared helper instead of a second fixed banner. Falls back to a
    // minimal link banner only if no toast stack exists (e.g. tests).
    const signInUrl = document.querySelector("meta[name='sign-in-url']")?.content || "/users/sign_in"
    if (document.getElementById("toast-stack")) {
      showToast("Session expired — please sign in to sync your offline entries.", { type: "error", duration: 10000 })
      return
    }

    const banner = document.createElement("div")
    banner.className = "toast-card toast-warning"
    banner.setAttribute("role", "alert")

    const span = document.createElement("span")
    span.textContent = "Session expired — please sign in to sync your offline entries."

    const link = document.createElement("a")
    link.href = signInUrl
    link.className = "underline font-semibold whitespace-nowrap"
    link.textContent = "Sign in"

    banner.append(span, link)
    document.body.appendChild(banner)

    setTimeout(() => banner.remove(), 10000)
  }

  #showSyncBanner(synced, failed) {
    // Consolidated with connectivity: one toast in #toast-stack, never a
    // second fixed banner competing with the sync-progress banner.
    if (failed > 0 && synced > 0) {
      showToast(`Synced ${synced} ${synced === 1 ? "entry" : "entries"}. ${failed} failed — tap Retry to try again.`, { type: "info" })
    } else if (failed > 0) {
      showToast(`Sync failed for ${failed} ${failed === 1 ? "entry" : "entries"}. Tap Retry to try again.`, { type: "error" })
    } else {
      showToast(`Synced ${synced} offline ${synced === 1 ? "entry" : "entries"} successfully.`, { type: "success" })
    }
  }
}
