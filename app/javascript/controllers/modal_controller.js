import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["wrapper", "summaryView", "metadataView", "recommendationView", "historyView", "recommendationButton", "summaryButton", "metadataButton", "historyButton"]

  connect() {
    super.connect();
    this.wrapperTarget.addEventListener('close', this.onModalClose.bind(this))
  }

  submitAndClose(event) {
    // Let the form submit normally
    // The modal will close automatically when redirected after successful submission
    const modal = document.getElementById('add_site_modal')
    if (modal) {
      modal.addEventListener('turbo:submit-end', () => {
        modal.close()
      }, { once: true })
    }
  }

  openModal() {
    this.wrapperTarget.classList.remove("hidden")
    this.wrapperTarget.showModal()
  }

  onModalClose() {
    this.wrapperTarget.classList.add("hidden")
  }

  showSummaryView() {
    this.hideAllViews()
    this.summaryViewTarget.classList.remove("hidden")
    this.updateButtonStyles(this.summaryButtonTarget)
  }

  showMetadataView() {
    this.hideAllViews()
    this.metadataViewTarget.classList.remove("hidden")
    this.updateButtonStyles(this.metadataButtonTarget)
  }

  showHistoryView() {
    this.hideAllViews()
    this.historyViewTarget.classList.remove("hidden")
    this.updateButtonStyles(this.historyButtonTarget)
  }

  showReccomendationView() {
    this.hideAllViews()
    this.recommendationViewTarget.classList.remove("hidden")
    this.updateButtonStyles(this.recommendationButtonTarget)
  }

  hideAllViews() {
    this.summaryViewTarget.classList.add("hidden")
    this.metadataViewTarget.classList.add("hidden")
    this.recommendationViewTarget.classList.add("hidden")
    this.historyViewTarget.classList.add("hidden")
  }

  updateButtonStyles(activeButton) {
    [this.summaryButtonTarget, this.metadataButtonTarget, this.recommendationButtonTarget, this.historyButtonTarget].forEach(button => {
      button.classList.remove("tab-active")
    })
    activeButton.classList.add("tab-active")
  }
}
