import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]

  connect() {
    // Always start with filter hidden
    this.toggleVisibility(true)
  }

  toggle() {
    const isVisible = this.contentTarget.classList.contains("hidden")
    this.toggleVisibility(isVisible)
    localStorage.setItem("filterVisible", isVisible)
  }

  toggleVisibility(show) {
    if (show) {
      this.contentTarget.classList.remove("hidden")
      this.contentTarget.classList.add("block")
      this.contentTarget.classList.remove("opacity-0")
      this.contentTarget.classList.add("opacity-100")
    } else {
      this.contentTarget.classList.add("hidden")
      this.contentTarget.classList.remove("block")
      this.contentTarget.classList.add("opacity-0")
      this.contentTarget.classList.remove("opacity-100")
    }
  }

  clearFilters(event) {
    event.preventDefault()
    // Find all form inputs and reset them
    const form = event.target.closest('form')
    if (form) {
      form.querySelectorAll('input, select').forEach(input => {
        if (input.type === 'hidden' && input.name === 'status') {
          input.value = '' // Reset status to empty (Backlog)
        } else {
          input.value = ''
        }
      })
      this.toggleVisibility(false)
      form.submit()
    }
  }

  submitForm(event) {
    this.toggleVisibility(false)
  }
}
