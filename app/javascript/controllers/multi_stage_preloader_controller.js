import {Controller} from "@hotwired/stimulus"

export default class extends Controller {

    STAGE_DURATION_SECONDS = 8;

    updateStageWrapperWidth(stageWrapper, currentStage) {
        if (currentStage) {
            stageWrapper.style.width = currentStage.scrollWidth + "px";
        }
    }

    animate() {
        let start = Date.now()
        let currentStage = this.element.querySelector('.stage.active');
        const stages = Array.from(this.element.querySelectorAll('.stage.inactive'));
        const stageWrapper = this.element.querySelector('.stages');
        this.updateStageWrapperWidth(stageWrapper, currentStage);
        const interval = setInterval(() => {
            if ((Date.now() - start) / 1000 > this.STAGE_DURATION_SECONDS) {
                start = Date.now();
                let nextStage = stages.shift()
                if (nextStage) {
                    currentStage.classList.replace("active", "complete");
                    setTimeout(() => {
                        this.updateStageWrapperWidth(stageWrapper, nextStage)
                    }, 500);
                    setTimeout(() => {
                        nextStage.classList.replace("inactive", "active");
                        currentStage = nextStage;
                    }, 500);
                }
                else {
                    clearInterval(interval);
                }
            }
        }, 250)
    }
}
