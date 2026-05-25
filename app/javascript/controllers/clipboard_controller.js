import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "button"]

  copy() {
    const text = this.sourceTarget.value
    const original = this.buttonTarget.textContent
    navigator.clipboard.writeText(text).then(() => {
      this.buttonTarget.textContent = this.buttonTarget.dataset.copiedText
      setTimeout(() => { this.buttonTarget.textContent = original }, 2000)
    }).catch(() => {
      this.buttonTarget.textContent = this.buttonTarget.dataset.failedText
      setTimeout(() => { this.buttonTarget.textContent = original }, 2000)
    })
  }
}
