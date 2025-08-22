import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["display", "button", "preloader"]

    static values = {
        documentId: Number,
    }

    async getRecommendationList() {
        try {
            this.buttonTarget.classList.add('hidden');
            this.preloaderTarget.classList.remove('hidden')
            let list = this.displayTarget.querySelector(".recommendation-list")
            if (list) {
                list.classList.add("hidden")
            }
            this.application.getControllerForElementAndIdentifier(this.preloaderTarget, 'multi-stage-preloader').animate();
            const response = await fetch(`/documents/${this.documentIdValue}/update_recommendation_inference`, {
                method: "PATCH",
                headers: {
                    "Content-Type": "application/json",
                    "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
                    "Accept": "application/json"
                },
            })
            if (response.ok) {
                const jsonRecommendationList = await response.json()
                this.displayTarget.innerHTML = jsonRecommendationList.html;
            } else {
                this.displayTarget.textContent = 'An error occurred getting the recommendation list for this document. Please try again later.';
                throw new Error("Response was not OK")
            }
        } catch (error) {
            console.error("Error getting the recommendation list document:", error)
            this.preloaderTarget.classList.add('hidden')
        }
    }
}
