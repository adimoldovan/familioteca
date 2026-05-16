import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "theme"
const DARK = "dark"
const LIGHT = "light"

export default class extends Controller {
  static targets = ["icon"]

  connect() {
    this.syncIcon()
  }

  toggle() {
    const root = document.documentElement
    const isDark = root.classList.toggle(DARK)
    try {
      localStorage.setItem(STORAGE_KEY, isDark ? DARK : LIGHT)
    } catch (e) {
      // Storage unavailable (Safari private mode etc.) — preference is per-session only.
    }
    this.syncIcon()
  }

  syncIcon() {
    if (!this.hasIconTarget) return
    const isDark = document.documentElement.classList.contains(DARK)
    this.iconTarget.textContent = isDark ? "☀" : "☾"
  }
}
