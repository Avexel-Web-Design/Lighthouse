import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["redScore", "blueScore", "redWin", "blueWin"]
  static values = {
    redScore: Number,
    blueScore: Number
  }

  connect() {
    this.updateResult()
  }

  updateResult() {
    if (!this.hasRedScoreValue || !this.hasBlueScoreValue) return
    const red = this.redScoreValue
    const blue = this.blueScoreValue

    if (this.hasRedWinTarget && this.hasBlueWinTarget) {
      if (red > blue) {
        this.redWinTarget.classList.remove("hidden")
        this.blueWinTarget.classList.add("hidden")
      } else if (blue > red) {
        this.blueWinTarget.classList.remove("hidden")
        this.redWinTarget.classList.add("hidden")
      } else {
        // Tie
        this.redWinTarget.classList.add("hidden")
        this.blueWinTarget.classList.add("hidden")
      }
    }
  }
}
