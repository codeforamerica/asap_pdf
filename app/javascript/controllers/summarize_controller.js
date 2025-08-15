import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["summaryValue", "button", "preloader"]

    static values = {
        documentId: Number,
    }

    async getSummary() {
        try {
            this.buttonTarget.classList.add('hidden');
            this.preloaderTarget.classList.remove('hidden')
            const response = await fetch(`/documents/${this.documentIdValue}/update_summary_inference`, {
                method: "PATCH",
                headers: {
                    "Content-Type": "application/json",
                    "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
                    "Accept": "application/json"
                },
            })
            if (response.ok) {
                const replacementSummary = await response.json()
                this.preloaderTarget.classList.add('hidden')
                this.element.innerHTML = replacementSummary.html
            } else {
                this.summaryValueTarget.textContent = 'An error occurred summarizing this document. Please try again later.';
                throw new Error("Response was not OK")
            }
        } catch (error) {
            console.error("Error summarizing document:", error)
            this.preloaderTarget.classList.add('hidden')
        }
    }
}
