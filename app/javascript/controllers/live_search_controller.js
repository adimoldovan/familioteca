import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  search() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      const url = new URL(window.location)
      const value = this.inputTarget.value.trim()
      if (value) {
        url.searchParams.set("q", value)
      } else {
        url.searchParams.delete("q")
      }
      Turbo.visit(url.toString(), { action: "replace" })
    }, 300)
  }

  clear() {
    this.inputTarget.value = ""
    this.search()
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
