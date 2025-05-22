from typing import List

from evaluation.utility.document import EvaluationWrapperBase, Document, Result
from evaluation.summary.mllmsummarization import evaluation
from evaluation.summary.rouge_score import calculate_rouge_score
from evaluation.utility.asap_inference import get_inference_for_document
from evaluation.utility.helpers import logger

class EvaluationWrapper(EvaluationWrapperBase):

    def evaluate(self, document: Document) -> List[Result]:
        output = []
        logger.info("Beginning summarization.")
        result = get_inference_for_document(document, self.inference_model_name, "summary", self.local_mode, self.page_limit)
        logger.info(
            "Summarization complete. Performing related evaluations."
        )
        document.ai_summary = result["summary"]
        # @todo abstract this.
        # @todo results could be created from a factory to prevent all the extra setting here.
        result = evaluation(
            self.branch_name, self.commit_sha, document, self.evaluation_model
        )
        logger.info("Calculating Rouge score.")
        result.evaluation_model = self.evaluation_model.model_name
        result.inference_model = self.inference_model_name
        output.append(dict(result))
        result = calculate_rouge_score(
            self.branch_name, self.commit_sha, document
        )
        logger.info("Evaluation complete.")
        result.inference_model = self.inference_model_name
        output.append(dict(result))
        return output
