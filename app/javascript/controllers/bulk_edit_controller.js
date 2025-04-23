import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["selectOne", "selectAll", "actions", "modal"]

    static values = {
        siteId: Number
    }

    store = {
        total: 0,
        checked: 0,
        toChange: {
            key: "status",
            value: "",
        }
    }

    connect() {
        this.updateSelectAllState()
        this.modalTarget.addEventListener('close', this.resetActionBar.bind(this))
    }

    handleCheckAll() {
        const isChecked = this.selectAllTarget.checked
        this.selectOneTargets.forEach(checkbox => {
            checkbox.checked = isChecked
        })
        this.updateCheckedCounts()
        this.updateActionBar()
    }

    handleCheckOne() {
        // Schedule state update for next frame
        this.updateCheckedCounts()
        this.updateSelectAllState()
        this.updateActionBar()
    }

    handleCloseActions() {
        this.selectAllTarget.checked = false;
        this.selectAllTarget.indeterminate = false;
        this.handleCheckAll()
    }

    handleConfirm() {
        let newState = {}
        newState[this.store.toChange.key] = this.store.toChange.value
        this.patchDocuments(newState)
    }

    handleMove(e) {
        this.store.key = "status";
        this.store.toChange.value = e.target.value;
        const title = "Confirm move"
        const message = `You are about to move ${this.store.checked} documents to "${this.store.toChange.value}"`
        this.updateModal(title, message)
    }

    resetActionBar() {
        const bulkEditMove = this.actionsTarget.querySelector('#bulk-edit-move')
        bulkEditMove.value="Choose Status"
        bulkEditMove.blur()
    }

    updateSelectAllState() {
        this.selectAllTarget.checked = (this.store.total > 0 && this.store.checked === this.store.total)
        this.selectAllTarget.indeterminate = this.store.checked > 0 && this.store.checked < this.store.total
    }

    updateCheckedCounts() {
        const checkboxes = this.selectOneTargets
        this.store.total = checkboxes.length
        this.store.checked = checkboxes.filter(checkbox => checkbox.checked).length
    }

    updateActionBar() {
        if (this.store.checked > 0) {
            this.actionsTarget.classList.remove("hidden");
        } else {
            this.actionsTarget.classList.add("hidden")
        }
        const counter = this.actionsTarget.querySelector('.checked-count span')
        counter.innerHTML = this.store.checked
    }

    updateModal(title, message) {
        this.modalTarget.querySelector('h3').innerHTML = title
        this.modalTarget.querySelector('p').innerHTML = message
        this.modalTarget.showModal();
    }

    async patchDocuments(newState) {
        let documents = []
        this.selectOneTargets.forEach((checkbox) => {
            if (checkbox.checked) {
                let document_id = checkbox.getAttribute("data-bulk-edit-document-id-value")
                documents.push(Object.assign({}, newState, {id: document_id}))
            }
        })
        try {
            const response = await fetch(`/sites/${this.siteIdValue}/documents/batch_update`, {
                method: "PATCH",
                headers: {
                    "Content-Type": "application/json",
                    "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
                    "Accept": "application/json"
                },
                body: JSON.stringify({
                    documents: documents,
                })
            })
            if (response.ok) {
                window.location.reload()
            } else {
                throw new Error("Response was not OK")
            }
        } catch (error) {
            console.error("Error updating documents:", error)
        }
    }
}