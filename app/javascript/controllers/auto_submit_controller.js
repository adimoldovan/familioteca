import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.submitHandler = () => this.submit()
    this.element.addEventListener("change", this.submitHandler)
  }

  disconnect() {
    this.element.removeEventListener("change", this.submitHandler)
  }

  submit() {
    const url = new URL(window.location)
    url.searchParams.set(this.element.name, this.element.value)
    Turbo.visit(url.toString(), { action: "replace" })
  }
}
