import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "select"]
  static values = {
    documentId: Number,
    field: String
  }

  connect() {
    // Hide select by default, show display
    if (this.hasSelectTarget) {
      this.selectTarget.classList.add("hidden")
    }
    // Add click outside listener
    document.addEventListener("click", this.handleClickOutside.bind(this))
  }

  disconnect() {
    // Clean up click outside listener
    document.removeEventListener("click", this.handleClickOutside.bind(this))
  }

  showSelect(event) {
    event.stopPropagation()
    this.displayTarget.classList.add("hidden")
    this.selectTarget.classList.remove("hidden")
    this.selectTarget.focus()
  }

  hideSelect() {
    this.displayTarget.classList.remove("hidden")
    this.selectTarget.classList.add("hidden")
  }

  handleClickOutside(event) {
    if (this.element && !this.element.contains(event.target)) {
      this.hideSelect()
    }
  }

  async updateValue(event) {
    const value = event.target.value
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    if (!csrfToken) {
      console.error('CSRF token not found')
      return
    }

    // Map field values to their corresponding route names
    const routeMap = {
      document_category: 'update_document_category',
      accessibility_recommendation: 'update_accessibility_recommendation',
      notes: 'update_notes'
    }

    const route = routeMap[this.fieldValue]
    if (!route) {
      console.error(`Unknown field: ${this.fieldValue}`)
      return
    }

    // Format the request body based on the field type
    const requestBody = this.fieldValue === 'notes'
      ? JSON.stringify({ document: { notes: value } })
      : JSON.stringify({ value: value })

    try {
      const response = await fetch(`/documents/${this.documentIdValue}/${route}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken
        },
        body: requestBody
      })

      if (response.ok) {
        const data = await response.json()
        // Preserve the magic wand icon when updating display text
        const icon = this.displayTarget.querySelector('i')
        this.displayTarget.innerHTML = ''
        if (icon) {
          icon.remove()
        }
        this.displayTarget.appendChild(document.createTextNode(' ' + data.display_text))
        this.hideSelect()

        // Add success animations
        this.displayTarget.classList.add('success-animation')

        // Create and add success icon
        const successIcon = document.createElement('i')
        successIcon.className = 'fas fa-check text-success text-xs ml-1 success-icon'
        this.displayTarget.appendChild(successIcon)

        // Remove scale animation after it completes
        setTimeout(() => {
          this.displayTarget.classList.remove('success-animation')
        }, 500)

        // Remove success icon after fade animation
        setTimeout(() => {
          successIcon.remove()
        }, 800)
      } else {
        console.error('Failed to update value:', await response.text())
      }
    } catch (error) {
      console.error('Error updating value:', error)
    }
  }
}
