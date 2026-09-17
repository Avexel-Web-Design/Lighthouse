import { Controller } from "@hotwired/stimulus"
import jsQR from "jsqr"
import {
  cameraErrorMessage,
  cameraSupported,
  getCameraPermissionState,
  requestCameraStream,
  stopCameraStream,
} from "lib/camera_access"
import { decode } from "lib/qr_payload"

/**
 * QR Scanner Controller
 *
 * Uses the device camera to scan QR codes containing scouting entry data.
 * Decodes the compact payload and submits it to the server for import.
 *
 * Targets:
 *   video   - Hidden <video> element for camera stream
 *   canvas  - Hidden <canvas> for frame extraction
 *   preview - Visible preview area showing the camera feed
 *   status  - Text element showing scan status
 *   result  - Container for showing import results
 *   list    - Container for appending imported entry results
 */
export default class extends Controller {
  static targets = ["video", "canvas", "preview", "status", "result", "list", "startBtn"]
  static values = {
    importUrl: String,   // POST endpoint for QR import
    scanning: { type: Boolean, default: false },
  }

  connect() {
    this._generation = (this._generation || 0) + 1
    this._starting = false
    this.animationId = null
    this.stream = null
    // Throttle jsQR (expensive) — scan at most every 250ms while the rAF
    // loop keeps running for a smooth preview. Also tracks the resume timer
    // so disconnect() never fires a tick after teardown.
    this._lastScanAt = 0
    this._resumeTimeout = null
    this.scanningValue = false
    if (this.hasStartBtnTarget) this.startBtnTarget.classList.remove("hidden")
    this.previewTarget.classList.add("hidden")

    if (!cameraSupported()) {
      this.statusTarget.textContent = "Camera access is not supported on this device or browser."
      this.statusTarget.className = "text-sm text-red-400 mt-3"

      if (this.hasStartBtnTarget) {
        this.startBtnTarget.disabled = true
        this.startBtnTarget.classList.add("opacity-60", "cursor-not-allowed")
      }
    }
  }

  disconnect() {
    if (this._resumeTimeout) {
      clearTimeout(this._resumeTimeout)
      this._resumeTimeout = null
    }
    this.stopScanning()
  }

  async start() {
    if (this.scanningValue || this._starting || this.stream) return
    this._starting = true
    const generation = this._generation

    try {
      const stream = await requestCameraStream()
      if (generation !== this._generation || !this.element.isConnected) {
        stopCameraStream(stream)
        return
      }
      this.stream = stream
      this.videoTarget.srcObject = stream
      this.videoTarget.setAttribute("playsinline", true)
      await this.videoTarget.play()
      if (generation !== this._generation || !this.element.isConnected) return

      this.scanningValue = true
      this.statusTarget.textContent = "Point camera at a QR code..."
      this.statusTarget.className = "text-sm text-gray-400 mt-3"

      if (this.hasStartBtnTarget) {
        this.startBtnTarget.classList.add("hidden")
      }
      this.previewTarget.classList.remove("hidden")

      this.tick()
    } catch (err) {
      const permission = await getCameraPermissionState()
      if (generation !== this._generation || !this.element.isConnected) return
      stopCameraStream(this.stream)
      this.stream = null
      this.statusTarget.textContent = cameraErrorMessage(err, permission)
      this.statusTarget.className = "text-sm text-red-400 mt-3"
    } finally {
      if (generation === this._generation) this._starting = false
    }
  }

  stop() {
    this.stopScanning()
    if (this.hasStartBtnTarget) {
      this.startBtnTarget.classList.remove("hidden")
    }
    this.previewTarget.classList.add("hidden")
    this.statusTarget.textContent = "Scanner stopped."
    this.statusTarget.className = "text-sm text-gray-400 mt-3"
  }

  stopScanning() {
    this._generation++
    this._starting = false
    this._request?.abort()
    this.scanningValue = false

    if (this._resumeTimeout) {
      clearTimeout(this._resumeTimeout)
      this._resumeTimeout = null
    }

    if (this.animationId) {
      cancelAnimationFrame(this.animationId)
      this.animationId = null
    }

    if (this.stream) {
      stopCameraStream(this.stream)
      this.stream = null
    }

    if (this.hasVideoTarget) {
      this.videoTarget.pause?.()
      this.videoTarget.srcObject = null
    }
  }

  tick() {
    if (!this.scanningValue) return

    const video = this.videoTarget
    if (video.readyState !== video.HAVE_ENOUGH_DATA) {
      this.animationId = requestAnimationFrame(() => this.tick())
      return
    }

    // Throttle: jsQR on every 60fps frame janks mobile CPUs. Run the decode
    // at most ~4x/sec; the rAF loop itself stays cheap.
    const now = performance.now()
    if (now - this._lastScanAt < 250) {
      this.animationId = requestAnimationFrame(() => this.tick())
      return
    }
    this._lastScanAt = now

    const canvas = this.canvasTarget
    const ctx = canvas.getContext("2d", { willReadFrequently: true })
    canvas.width = video.videoWidth
    canvas.height = video.videoHeight
    ctx.drawImage(video, 0, 0, canvas.width, canvas.height)

    const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height)
    const code = jsQR(imageData.data, imageData.width, imageData.height, {
      inversionAttempts: "dontInvert",
    })

    if (code && code.data) {
      this.handleScan(code.data)
    } else {
      this.animationId = requestAnimationFrame(() => this.tick())
    }
  }

  async handleScan(rawData) {
    const generation = this._generation
    // Pause scanning while processing
    this.scanningValue = false

    this.statusTarget.textContent = "QR code detected! Importing..."
    this.statusTarget.className = "text-sm text-orange-400 mt-3"

    try {
      const entry = decode(rawData)
      await this.submitEntry(entry)
    } catch (err) {
      console.error("QR decode/import failed:", err)
      this.appendResult("error", "Invalid QR code — not a Lighthouse scouting entry.", null)
    }

    if (generation !== this._generation || !this.element.isConnected) return
    // Resume scanning after a short delay
    if (this._resumeTimeout) clearTimeout(this._resumeTimeout)
    this._resumeTimeout = setTimeout(() => {
      this._resumeTimeout = null
      if (this.stream) {
        this.scanningValue = true
        this.statusTarget.textContent = "Scanning for next QR code..."
        this.statusTarget.className = "text-sm text-gray-400 mt-3"
        this.tick()
      }
    }, 2000)
  }

  async submitEntry(entry) {
    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content
    const generation = this._generation
    this._request = new AbortController()

    try {
      const response = await fetch(this.importUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken,
        },
        credentials: "same-origin",
        signal: this._request.signal,
        body: JSON.stringify({ entry }),
      })

      if (!response.ok) {
        const text = await response.text()
        throw new Error(`Server error: ${response.status} ${text}`)
      }

      const result = await response.json()
      if (generation !== this._generation || !this.element.isConnected) return

      if (result.status === "created") {
        this.appendResult("created", `Team ${result.team_number} — ${result.match_name}`, result.id)
      } else if (result.status === "existing") {
        this.appendResult("existing", `Team ${result.team_number} — ${result.match_name} (already exists)`, result.id)
      } else if (result.status === "updated") {
        this.appendResult("updated", `Team ${result.team_number} — ${result.match_name} (updated — newer data)`, result.id)
      } else if (result.status === "skipped") {
        this.appendResult("skipped", `Team ${result.team_number} — ${result.match_name} (server copy is newer)`, result.id)
      } else {
        this.appendResult("error", `Import failed: ${(result.errors || []).join(", ")}`, null)
      }
    } catch (err) {
      if (generation !== this._generation) return
      console.error("Import request failed:", err)
      this.appendResult("error", `Network error: ${err.message}`, null)
    }
  }

  appendResult(status, message, entryId) {
    if (this.hasResultTarget) {
      this.resultTarget.classList.remove("hidden")
    }

    const colors = {
      created:  "text-emerald-400 border-emerald-500/30",
      updated:  "text-blue-400 border-blue-500/30",
      existing: "text-amber-400 border-amber-500/30",
      skipped:  "text-gray-400 border-gray-500/30",
      error:    "text-red-400 border-red-500/30",
    }

    // Static glyphs only — never interpolated HTML. Rendered via textContent.
    const icons = {
      created:  "✓",
      updated:  "↻",
      existing: "—",
      skipped:  "→",
      error:    "✕",
    }

    const div = document.createElement("div")
    div.className = `flex items-center gap-2 p-3 rounded-lg border bg-gray-900/50 ${colors[status] || colors.error}`
    // Text label (not color-only) for AT.
    div.setAttribute("role", status === "error" ? "alert" : "status")

    const icon = document.createElement("span")
    icon.className = "text-lg font-bold"
    icon.setAttribute("aria-hidden", "true")
    icon.textContent = icons[status] || "?"
    div.appendChild(icon)

    const text = document.createElement("span")
    text.className = "text-sm flex-1"
    // Server-controlled strings (team number, match name, error list) enter
    // the DOM via textContent only — never innerHTML.
    text.textContent = message
    div.appendChild(text)

    // entryId comes from the server JSON response. Only render a link for
    // integer ids to avoid javascript: / path-traversal injection.
    const numericId = Number(entryId)
    if (Number.isInteger(numericId) && numericId > 0) {
      const link = document.createElement("a")
      link.href = `/scouting_entries/${numericId}`
      link.className = "text-xs text-orange-400 hover:text-orange-300 underline"
      link.textContent = "View"
      div.appendChild(link)
    }

    if (this.hasListTarget) {
      this.listTarget.prepend(div)
    }
  }
}
