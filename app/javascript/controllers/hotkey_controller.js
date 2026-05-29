import { Controller } from "@hotwired/stimulus"

// Clicks the element when the configured key is pressed.
// Ignores the key while the user is typing in a form field.
export default class extends Controller {
  static values = { key: String }

  connect() {
    this.handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.handleKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown)
  }

  handleKeydown(event) {
    // Require an unmodified press so we don't hijack deliberate uppercase typing
    // (Shift+S) or browser/OS shortcuts. toLowerCase keeps it working under Caps Lock.
    if (event.metaKey || event.ctrlKey || event.altKey || event.shiftKey) return
    if (this.isTyping(event.target)) return
    if (event.key.toLowerCase() !== this.keyValue.toLowerCase()) return

    event.preventDefault()
    this.element.click()
  }

  isTyping(target) {
    const tag = target.tagName
    const role = target.getAttribute?.("role")
    return (
      tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT" ||
      target.isContentEditable ||
      role === "textbox" || role === "combobox" || role === "searchbox"
    )
  }
}
