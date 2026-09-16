import { Controller } from "@hotwired/stimulus"
import {
  cameraErrorMessage,
  getCameraPermissionState,
  listVideoInputs,
  requestCameraStream,
  stopCameraStream,
} from "lib/camera_access"

export default class extends Controller {
  static targets = [
    "uploadInput",
    "cameraInput",
    "summary",
    "cameraPanel",
    "video",
    "canvas",
    "status",
    "captureButton",
    "previews",
    "switchButton",
  ]

  connect() {
    this.stream = null
    this.previewUrls = []
    this.availableCameras = []
    this.activeCameraIndex = 0
    this.preferredFacingMode = "environment"
    this.updateSummary()
  }

  disconnect() {
    this.closeCamera()
    this.#clearPreviewUrls()
  }

  openUpload() {
    if (this.hasUploadInputTarget) this.uploadInputTarget.click()
  }

  async openCamera() {
    if (!this.hasCameraPanelTarget || !this.hasVideoTarget) return

    this.cameraPanelTarget.classList.remove("hidden")
    this.#setStatus("Opening camera...", "text-sm text-gray-400")
    this.#setCaptureEnabled(false)
    this.#setSwitchEnabled(false)

    try {
      await this.#startCamera()
      this.#setCaptureEnabled(true)
      this.#setStatus("Camera is live. Capture a photo when you're ready.", "text-sm text-emerald-400")
    } catch (error) {
      this.#setStatus(cameraErrorMessage(error, await getCameraPermissionState()), "text-sm text-red-400")
    }
  }

  async switchCamera() {
    if (this.availableCameras.length < 2) return

    this.activeCameraIndex = (this.activeCameraIndex + 1) % this.availableCameras.length
    this.#setStatus("Switching camera...", "text-sm text-gray-400")
    this.#setCaptureEnabled(false)
    this.#setSwitchEnabled(false)

    try {
      await this.#startCamera({ preserveSelection: true })
      this.#setCaptureEnabled(true)
      this.#setStatus("Camera switched. Capture a photo when you're ready.", "text-sm text-emerald-400")
    } catch (error) {
      this.#setStatus(cameraErrorMessage(error, await getCameraPermissionState()), "text-sm text-red-400")
    }
  }

  closeCamera() {
    this.#stopStream()

    if (this.hasVideoTarget) {
      this.videoTarget.pause()
      this.videoTarget.srcObject = null
    }

    if (this.hasCameraPanelTarget) {
      this.cameraPanelTarget.classList.add("hidden")
    }

    this.#setCaptureEnabled(false)
    this.#setSwitchEnabled(this.availableCameras.length > 1)
  }

  async capturePhoto() {
    if (!this.stream || !this.hasVideoTarget || !this.hasCanvasTarget || !this.hasCameraInputTarget) return

    const video = this.videoTarget
    if (video.videoWidth === 0 || video.videoHeight === 0) {
      this.#setStatus("Camera is still warming up. Try again in a moment.", "text-sm text-amber-300")
      return
    }

    const canvas = this.canvasTarget
    const context = canvas.getContext("2d")
    canvas.width = video.videoWidth
    canvas.height = video.videoHeight
    context.drawImage(video, 0, 0, canvas.width, canvas.height)

    const blob = await new Promise((resolve) => canvas.toBlob(resolve, "image/jpeg", 0.92))
    if (!blob) {
      this.#setStatus("Couldn't capture that photo. Try again.", "text-sm text-red-400")
      return
    }

    const timestamp = new Date().toISOString().replace(/[:.]/g, "-")
    const photo = new File([blob], `pit-photo-${timestamp}.jpg`, {
      type: "image/jpeg",
      lastModified: Date.now(),
    })

    this.#appendFile(this.cameraInputTarget, photo)
    this.updateSummary()
    this.#setStatus("Photo added. Capture another one or tap Done.", "text-sm text-emerald-400")
  }

  updateSummary() {
    if (!this.hasSummaryTarget) return

    const files = this.#selectedFiles()
    if (files.length === 0) {
      this.summaryTarget.textContent = "No photos selected yet."
      this.#renderPreviews([])
      return
    }

    this.summaryTarget.textContent = `${files.length} photo${files.length === 1 ? "" : "s"} ready to upload.`
    this.#renderPreviews(files)
  }

  #appendFile(input, file) {
    const transfer = new DataTransfer()
    Array.from(input.files || []).forEach((existingFile) => transfer.items.add(existingFile))
    transfer.items.add(file)
    input.files = transfer.files
  }

  async #startCamera({ preserveSelection = false } = {}) {
    this.#stopStream()

    let stream = await requestCameraStream(this.#cameraRequestOptions())
    this.stream = stream
    this.videoTarget.srcObject = stream
    this.videoTarget.setAttribute("playsinline", true)
    await this.videoTarget.play()

    this.availableCameras = await listVideoInputs()

    if (!preserveSelection) {
      this.activeCameraIndex = this.#defaultCameraIndex()

      const desiredCamera = this.availableCameras[this.activeCameraIndex]
      const activeDeviceId = this.stream?.getVideoTracks?.()[0]?.getSettings?.().deviceId

      if (desiredCamera?.deviceId && desiredCamera.deviceId !== activeDeviceId) {
        this.#stopStream()
        stream = await requestCameraStream({ deviceId: desiredCamera.deviceId })
        this.stream = stream
        this.videoTarget.srcObject = stream
        await this.videoTarget.play()
      }
    } else {
      this.activeCameraIndex = this.#matchingCameraIndex() ?? this.activeCameraIndex
    }

    this.#setSwitchEnabled(this.availableCameras.length > 1)
  }

  #stopStream() {
    if (!this.stream) return

    stopCameraStream(this.stream)
    this.stream = null
  }

  #cameraRequestOptions() {
    const selectedCamera = this.availableCameras[this.activeCameraIndex]
    if (selectedCamera?.deviceId) {
      return { deviceId: selectedCamera.deviceId }
    }

    return { facingMode: this.preferredFacingMode }
  }

  #defaultCameraIndex() {
    const backCameraIndex = this.availableCameras.findIndex((camera) => {
      const label = camera.label.toLowerCase()
      return label.includes("back") || label.includes("rear") || label.includes("environment")
    })

    return backCameraIndex >= 0 ? backCameraIndex : 0
  }

  #matchingCameraIndex() {
    const activeTrack = this.stream?.getVideoTracks?.()[0]
    const activeDeviceId = activeTrack?.getSettings?.().deviceId
    if (!activeDeviceId) return null

    const matchingIndex = this.availableCameras.findIndex((camera) => camera.deviceId === activeDeviceId)
    return matchingIndex >= 0 ? matchingIndex : null
  }

  #selectedFiles() {
    return [
      ...(this.hasUploadInputTarget ? Array.from(this.uploadInputTarget.files || []) : []),
      ...(this.hasCameraInputTarget ? Array.from(this.cameraInputTarget.files || []) : []),
    ]
  }

  #renderPreviews(files) {
    if (!this.hasPreviewsTarget) return

    this.#clearPreviewUrls()
    // replaceChildren (not innerHTML="") — file names are user-controlled
    // and must only ever enter the DOM via textContent below.
    this.previewsTarget.replaceChildren()
    this.previewsTarget.classList.toggle("hidden", files.length === 0)

    files.forEach((file) => {
      const objectUrl = URL.createObjectURL(file)
      this.previewUrls.push(objectUrl)

      const card = document.createElement("figure")
      card.className = "overflow-hidden rounded-lg border border-gray-800 bg-gray-950"

      const image = document.createElement("img")
      image.src = objectUrl
      image.alt = file.name
      image.className = "h-24 w-full object-cover"

      const caption = document.createElement("figcaption")
      caption.className = "truncate px-2 py-1.5 text-xs text-gray-400"
      caption.textContent = file.name

      card.append(image, caption)
      this.previewsTarget.append(card)
    })
  }

  #clearPreviewUrls() {
    this.previewUrls.forEach((url) => URL.revokeObjectURL(url))
    this.previewUrls = []
  }

  #setStatus(message, className) {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = message
    this.statusTarget.className = className
  }

  #setCaptureEnabled(enabled) {
    if (!this.hasCaptureButtonTarget) return

    this.captureButtonTarget.disabled = !enabled
    this.captureButtonTarget.classList.toggle("opacity-50", !enabled)
    this.captureButtonTarget.classList.toggle("cursor-not-allowed", !enabled)
  }

  #setSwitchEnabled(enabled) {
    if (!this.hasSwitchButtonTarget) return

    this.switchButtonTarget.disabled = !enabled
    this.switchButtonTarget.classList.toggle("opacity-50", !enabled)
    this.switchButtonTarget.classList.toggle("cursor-not-allowed", !enabled)
  }
}
