import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["button", "preloader", "documentList"]

    static values = {
        siteId: Number,
    }
    async createReport() {
        try {
            this.buttonTarget.classList.add("hidden");
            this.preloaderTarget.classList.remove("hidden");
            const response = await fetch(`/sites/${this.siteIdValue}/create_workflow_audit_report`, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
                    "Accept": "application/json"
                },
            })
            if (response.ok) {
                const jsonSummary = await response.json()
                this.documentListTarget.outerHTML = jsonSummary.html;
                this.preloaderTarget.classList.add('hidden')
                this.buttonTarget.classList.remove("hidden");
            } else {
                this.displayTarget.textContent = 'An error occurred summarizing this document. Please try again later.';
                throw new Error("Response was not OK")
            }
        } catch (error) {
            console.error("Error summarizing document:", error)
            this.preloaderTarget.classList.add('hidden')
        }
    }
}
