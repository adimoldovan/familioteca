import { Controller } from "@hotwired/stimulus"

const FOCUSABLE = [
  'a[href]',
  'button:not([disabled])',
  'input:not([disabled]):not([type="hidden"])',
  'select:not([disabled])',
  'textarea:not([disabled])',
  '[tabindex]:not([tabindex="-1"])'
].join(", ")

export default class extends Controller {
  static targets = ["panel", "trigger"]

  initialize() {
    this.handleKeydown = this.handleKeydown.bind(this)
  }

  open() {
    if (this.panelTarget.classList.contains("is-open")) return

    this.previouslyFocused = document.activeElement
    this.panelTarget.classList.add("is-open")
    this.panelTarget.removeAttribute("aria-hidden")
    if (this.hasTriggerTarget) this.triggerTarget.setAttribute("aria-expanded", "true")
    this.setBackgroundInert(true)
    document.addEventListener("keydown", this.handleKeydown)

    requestAnimationFrame(() => {
      const firstFocusable = this.panelTarget.querySelector(FOCUSABLE)
      if (firstFocusable) firstFocusable.focus()
    })
  }

  close() {
    if (!this.panelTarget.classList.contains("is-open")) return

    this.panelTarget.classList.remove("is-open")
    this.panelTarget.setAttribute("aria-hidden", "true")
    if (this.hasTriggerTarget) this.triggerTarget.setAttribute("aria-expanded", "false")
    this.setBackgroundInert(false)
    document.removeEventListener("keydown", this.handleKeydown)

    if (this.previouslyFocused) {
      this.previouslyFocused.focus()
      this.previouslyFocused = null
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown)
    this.panelTarget.classList.remove("is-open")
    this.panelTarget.setAttribute("aria-hidden", "true")
    if (this.hasTriggerTarget) this.triggerTarget.setAttribute("aria-expanded", "false")
    this.setBackgroundInert(false)
    this.previouslyFocused = null
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.close()
    } else if (event.key === "Tab") {
      this.trapFocus(event)
    }
  }

  trapFocus(event) {
    const focusables = [...this.panelTarget.querySelectorAll(FOCUSABLE)]
    if (focusables.length === 0) return

    const first = focusables[0]
    const last = focusables[focusables.length - 1]

    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault()
      first.focus()
    }
  }

  setBackgroundInert(inert) {
    const header = this.element.querySelector(".site-header__bar")
    const main = document.querySelector("main.site-main")
    if (inert) {
      header?.setAttribute("inert", "")
      main?.setAttribute("inert", "")
    } else {
      header?.removeAttribute("inert")
      main?.removeAttribute("inert")
    }
  }
}
