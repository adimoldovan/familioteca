import { Controller } from "@hotwired/stimulus"

export const STORAGE_KEY = "theme"
const DARK = "dark"
const LIGHT = "light"

export default class extends Controller {
  static targets = ["moon", "sun"]

  connect() {
    this.syncIcons()
  }

  toggle() {
    const root = document.documentElement
    const isDark = root.classList.toggle(DARK)
    try {
      localStorage.setItem(STORAGE_KEY, isDark ? DARK : LIGHT)
    } catch {
      // Storage unavailable (Safari private mode etc.)
    }
    this.syncIcons()
  }

  syncIcons() {
    const isDark = document.documentElement.classList.contains(DARK)
    if (this.hasMoonTarget) this.moonTarget.style.display = isDark ? "none" : "block"
    if (this.hasSunTarget) this.sunTarget.style.display = isDark ? "block" : "none"
  }
}
