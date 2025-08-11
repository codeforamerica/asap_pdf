import {Controller} from "@hotwired/stimulus"

// Connects to data-controller="feedback"
export default class extends Controller {

    static targets = ["sentimentPositive", "sentimentNegative", "additionalFeedback", "status", "comment", "inference"]

    static values = {
        userId: Number
    }

    store = {
        "sentiment": null,
        "comment": "",
    }

    connect() {
        if (this.sentimentPositiveTarget.classList.contains("active")) {
            this.store.sentiment = "positive";
        } else if (this.sentimentNegativeTarget.classList.contains("active")) {
            this.store.sentiment = "negative";
        }
    }

    handleFeedback(e) {
        e.preventDefault();
        let feedbackEl = e.target;
        if (feedbackEl.tagName === "I") {
            feedbackEl = feedbackEl.parentElement
        }
        this.store.sentiment = feedbackEl.dataset.sentiment;
        this.setWidgetDisplay();
        this.patchFeedback();
    }

    handleSubmit(e) {
        e.preventDefault();
        this.store.comment = this.commentTarget.value;
        this.patchFeedback();
    }

    setWidgetDisplay() {
        if (this.store.sentiment === "negative") {
            this.additionalFeedbackTarget.classList.remove("collapsed");
            this.sentimentNegativeTarget.classList.add("active");
            this.sentimentPositiveTarget.classList.remove("active");
        } else {
            this.additionalFeedbackTarget.classList.add("collapsed");
            this.sentimentNegativeTarget.classList.remove("active");
            this.sentimentPositiveTarget.classList.add("active");
            // Clear any existing comment text.
            this.store.comment = "";
            this.commentTarget.value = "";
        }
    }

    getInferences() {
        let selections = [];
        this.inferenceTargets.forEach((inferenceTarget) => {
            selections.push(inferenceTarget.dataset.inferenceId);
        });
        return selections;
    }

    showErrorMessage() {
        let wrapper = this.element.querySelector(".feedback-interface")
        wrapper.textContent = "There was an error saving your feedback. Please try again later.";
    }

    async patchFeedback() {
        this.statusTarget.classList.add("hidden");
        try {
            const headers = {
                "Content-Type": "application/json",
                "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
                "Accept": "application/json"
            }
            let deleteData = {"feedback_items": []};
            this.getInferences(false).map((inference_id) => {
                deleteData["feedback_items"].push({"document_inference_id": inference_id, "user_id": this.userIdValue})
            })
            const deleteRequest = await fetch("/feedback_items/delete_items", {
                method: "DELETE",
                headers: headers,
                body: JSON.stringify(deleteData)
            })
            if (!deleteRequest.ok) {
                this.showErrorMessage();
                throw new Error("Failed to delete previous feedback items.");
            }
            let patchData = {"feedback_items": []};
            this.getInferences(true).map((inference_id) => {
                patchData["feedback_items"].push(Object.assign({
                    "document_inference_id": inference_id,
                    "user_id": this.userIdValue
                }, this.store))
            })
            const patchResponse = await fetch("/feedback_items/update_feedback_items", {
                method: "PATCH",
                headers: headers,
                body: JSON.stringify(patchData)
            })
            if (patchResponse.ok) {
                this.statusTarget.classList.remove("hidden");
            } else {
                this.showErrorMessage();
                throw new Error("Failed to update new feedback items.")
            }
        } catch (error) {
            console.error("Error updating documents:", error)
        }
    }

}
