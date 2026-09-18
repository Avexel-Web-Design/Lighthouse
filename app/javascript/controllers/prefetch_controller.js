import { Controller } from "@hotwired/stimulus"
import { openDB, EVENT_DATA_STORE } from "lib/lighthouse_db"

/**
 * Prefetches all event pages for offline use when an event is selected/synced.
 *
 * On connect, checks if the current event's pages have been recently prefetched.
 * If not (or if stale), fetches the offline manifest and sends URLs to the
 * service worker for background caching.
 *
 * Also supports a manual "cache" action triggered by a button, which shows
 * real-time progress via targets (button label, progress bar, status text).
 *
 * Usage (auto):
 *   <div data-controller="prefetch" data-prefetch-event-id-value="123" data-prefetch-manifest-url-value="/events/123/offline_manifest">
 *
 * Usage (manual button):
 *   <button data-action="prefetch#cache" data-prefetch-target="cacheButton">Cache for Offline</button>
 *   <div data-prefetch-target="progressContainer" class="hidden">
 *     <div data-prefetch-target="progressBar" style="width: 0%"></div>
 *     <span data-prefetch-target="progressText"></span>
 *   </div>
 */
export default class extends Controller {
  static values = {
    eventId: String,
    manifestUrl: String,
    auto: { type: Boolean, default: true }
  }

  static targets = ["cacheButton", "progressContainer", "progressBar", "progressText"]

  // Shared across all prefetch instances on the page (dashboard + event page
  // can each mount one): debounce concurrent auto-prefetches for the same
  // event so N controllers trigger at most one manifest fetch + SW message.
  static _debounceTimers = {}
  static _inflight = {}

  connect() {
    this._caching = false
    this._manifestTruncated = false
    this._manifestTotal = null

    // Listen for SW progress messages
    this._onSwMessage = (event) => this.#handleSwMessage(event)
    navigator.serviceWorker?.addEventListener("message", this._onSwMessage)

    // Skip auto-prefetch if disabled (manual-only instances)
    if (!this.autoValue) return

    // Only auto-prefetch when online
    if (!navigator.onLine) return
    if (!this.eventIdValue || !this.manifestUrlValue) return

    // Debounce: coalesce multiple connect()s (Turbo restores, multiple
    // instances) into one check per event per 2s window.
    const key = this.eventIdValue
    if (this.constructor._debounceTimers[key]) {
      clearTimeout(this.constructor._debounceTimers[key])
    }
    this.constructor._debounceTimers[key] = setTimeout(() => {
      delete this.constructor._debounceTimers[key]
      if (!this.element.isConnected) return
      this.#checkAndPrefetch()
    }, 500)
  }

  disconnect() {
    navigator.serviceWorker?.removeEventListener("message", this._onSwMessage)
  }

  // --- Actions ---

  /**
   * Manual cache action — triggered by a button click.
   * Bypasses the staleness check and forces a full prefetch.
   */
  async cache() {
    if (this._caching) return
    if (!navigator.onLine) {
      this.#updateStatus("You are offline")
      return
    }
    if (!this.manifestUrlValue) return

    this._caching = true
    this.#showCachingUI()

    try {
      await this.#prefetch()
      // Final state is set by #handlePrefetchComplete via SW message
    } catch (error) {
      console.warn("[Lighthouse] Manual cache failed:", error)
      this.#updateStatus("Caching failed")
      this.#resetCacheButton()
    }
  }

  // --- Private ---

  async #checkAndPrefetch() {
    // In-flight guard: if another instance already started a prefetch for
    // this event, piggyback instead of fetching the manifest twice.
    const key = this.eventIdValue
    if (this.constructor._inflight[key]) {
      try { await this.constructor._inflight[key] } catch { /* ignore */ }
      return
    }

    const run = this.#checkAndPrefetchInner()
    this.constructor._inflight[key] = run
    try {
      await run
    } finally {
      delete this.constructor._inflight[key]
    }
  }

  async #checkAndPrefetchInner() {
    try {
      const db = await openDB()
      const tx = db.transaction(EVENT_DATA_STORE, "readonly")
      const store = tx.objectStore(EVENT_DATA_STORE)

      const existing = await new Promise((resolve, reject) => {
        const req = store.get(this.eventIdValue)
        req.onsuccess = () => resolve(req.result)
        req.onerror = () => reject(req.error)
      })

      db.close()

      // Re-prefetch if the cache version changed (e.g. after a SW update that
      // purged the old cache) even if the timestamp is still fresh.
      const currentCacheVersion = document.querySelector('meta[name="sw-cache-version"]')?.content

      if (existing?.prefetched_at) {
        const versionMatch = existing.cache_version === currentCacheVersion
        const elapsed = Date.now() - new Date(existing.prefetched_at).getTime()
        if (versionMatch && elapsed < 60 * 60 * 1000) return
      }

      await this.#prefetch()
    } catch (error) {
      console.warn("[Lighthouse] Prefetch check failed:", error)
    }
  }

  async #prefetch() {
    try {
      // Fetch the manifest of all URLs to cache
      const response = await fetch(this.manifestUrlValue, {
        credentials: "same-origin",
        headers: { "Accept": "application/json" }
      })

      if (!response.ok) {
        console.warn("[Lighthouse] Failed to fetch offline manifest:", response.status)
        this.#resetCacheButton()
        return
      }

      const { urls, truncated, total } = await response.json()
      this._manifestTruncated = Boolean(truncated)
      this._manifestTotal = Number.isFinite(total) ? total : null

      if (!urls || urls.length === 0) {
        this.#updateStatus("No pages to cache")
        this.#resetCacheButton()
        return
      }

      if (this._manifestTruncated) {
        const totalCount = this._manifestTotal
        const message = totalCount ? `Caching first ${urls.length} of ${totalCount} pages` : `Caching first ${urls.length} pages`
        this.#updateStatus(message)
      }

      // Send URLs to the service worker for background prefetching
      const sw = navigator.serviceWorker?.controller
      if (sw) {
        sw.postMessage({ type: "prefetch-urls", urls })
      } else {
        // Fallback: prefetch directly if no SW controller
        await this.#prefetchDirect(urls)
      }

      // Record the prefetch timestamp
      await this.#recordPrefetch()
    } catch (error) {
      console.warn("[Lighthouse] Prefetch failed:", error)
      this.#resetCacheButton()
    }
  }

  async #prefetchDirect(urls) {
    // The SW may be registered but not yet controlling this page.
    // Wait for it to become ready and message it directly.
    try {
      const registration = await navigator.serviceWorker?.ready
      if (registration?.active) {
        registration.active.postMessage({ type: "prefetch-urls", urls })
        return
      }
    } catch { /* SW not available */ }

    // Last resort: cache directly via the Cache API.
    // Read cache version from meta tag (set by Rails from config.sw_cache_version)
    try {
      const cacheName = document.querySelector('meta[name="sw-cache-version"]')?.content || "lighthouse-v6"
      const cache = await caches.open(cacheName)
      const concurrency = 3
      const total = urls.length
      let cached = 0

      for (let i = 0; i < urls.length; i += concurrency) {
        const batch = urls.slice(i, i + concurrency)
        await Promise.allSettled(
          batch.map(async (url) => {
            try {
              const response = await fetch(url, {
                credentials: "same-origin",
                headers: { "Accept": "text/html" }
              })
              if (response.ok) {
                if (response.redirected && response.url.includes("/users/sign_in")) return
                await cache.put(this.#htmlCacheKey(url), response.clone())
                cached++
              }
            } catch { /* skip */ }
          })
        )
        // Update progress locally since SW messages won't fire
        this.#handlePrefetchProgress({ cached, total })
      }
      this.#handlePrefetchComplete({ cached, total })
    } catch { /* Cache API not available */ }
  }

  async #recordPrefetch() {
    try {
      const db = await openDB()
      const tx = db.transaction(EVENT_DATA_STORE, "readwrite")
      const store = tx.objectStore(EVENT_DATA_STORE)

      // Read existing data (if any) and update with prefetch timestamp
      const existing = await new Promise((resolve, reject) => {
        const req = store.get(this.eventIdValue)
        req.onsuccess = () => resolve(req.result)
        req.onerror = () => reject(req.error)
      })

      const record = existing || { event_id: this.eventIdValue }
      record.prefetched_at = new Date().toISOString()
      record.cache_version = document.querySelector('meta[name="sw-cache-version"]')?.content
      store.put(record)

      await new Promise((resolve, reject) => {
        tx.oncomplete = resolve
        tx.onerror = () => reject(tx.error)
      })

      db.close()
    } catch (error) {
      console.warn("[Lighthouse] Failed to record prefetch:", error)
    }
  }

  // --- SW message handling for progress ---

  #handleSwMessage(event) {
    const data = event.data
    if (!data) return

    if (data.type === "prefetch-progress") {
      this.#handlePrefetchProgress(data)
    } else if (data.type === "prefetch-complete") {
      this.#handlePrefetchComplete(data)
    }
  }

  #handlePrefetchProgress({ completed, cached, total }) {
    const completedCount = Number.isFinite(cached) ? cached : completed
    const pct = total > 0 ? Math.round((completedCount / total) * 100) : 0

    if (this.hasProgressContainerTarget) {
      this.progressContainerTarget.classList.remove("hidden")
    }
    if (this.hasProgressBarTarget) {
      this.progressBarTarget.style.width = `${pct}%`
    }
    if (this.hasProgressTextTarget) {
      this.progressTextTarget.textContent = `${completedCount} / ${total} pages`
    }
    if (this.hasCacheButtonTarget) {
      this.cacheButtonTarget.disabled = true
      this.cacheButtonTarget.textContent = `Caching... ${pct}%`
    }
  }

  #handlePrefetchComplete({ total, cached, completed }) {
    this._caching = false

    const completedCount = Number.isFinite(cached) ? cached : (Number.isFinite(completed) ? completed : total)
    const pct = total > 0 ? Math.round((completedCount / total) * 100) : 0

    if (this.hasProgressBarTarget) {
      this.progressBarTarget.style.width = `${pct}%`
    }
    if (this.hasProgressTextTarget) {
      if (this._manifestTruncated) {
        const totalCount = this._manifestTotal || total
        this.progressTextTarget.textContent = `Cached ${completedCount} of ${totalCount} pages`
      } else {
        this.progressTextTarget.textContent = `${completedCount} pages cached`
      }
    }
    if (this.hasCacheButtonTarget) {
      this.cacheButtonTarget.disabled = false
      this.cacheButtonTarget.textContent = "Cached"
      this.cacheButtonTarget.classList.remove("bg-gray-800", "hover:bg-gray-700", "text-gray-300")
      this.cacheButtonTarget.classList.add("bg-green-600/20", "text-green-400", "border-green-500/30")
    }

    // Reset button text after a delay
    setTimeout(() => {
      if (this.hasCacheButtonTarget) {
        this.cacheButtonTarget.textContent = "Cache for Offline"
        this.cacheButtonTarget.classList.remove("bg-green-600/20", "text-green-400", "border-green-500/30")
        this.cacheButtonTarget.classList.add("bg-gray-800", "hover:bg-gray-700", "text-gray-300")
      }
      if (this.hasProgressContainerTarget) {
        this.progressContainerTarget.classList.add("hidden")
      }
    }, 5000)
  }

  // --- UI helpers ---

  #showCachingUI() {
    if (this.hasCacheButtonTarget) {
      this.cacheButtonTarget.disabled = true
      this.cacheButtonTarget.textContent = "Preparing..."
    }
    if (this.hasProgressContainerTarget) {
      this.progressContainerTarget.classList.remove("hidden")
    }
    if (this.hasProgressBarTarget) {
      this.progressBarTarget.style.width = "0%"
    }
    if (this.hasProgressTextTarget) {
      this.progressTextTarget.textContent = "Fetching manifest..."
    }
  }

  #updateStatus(text) {
    if (this.hasProgressTextTarget) {
      this.progressTextTarget.textContent = text
    }
  }

  #resetCacheButton() {
    this._caching = false
    if (this.hasCacheButtonTarget) {
      this.cacheButtonTarget.disabled = false
      this.cacheButtonTarget.textContent = "Cache for Offline"
    }
  }

  #htmlCacheKey(url) {
    return new Request(url, {
      headers: {
        "Accept": "text/html",
        "Turbo-Visit": "true"
      }
    })
  }

}
