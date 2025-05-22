from typing import List

from evaluation.exception.deterministic_score import evaluate_archival_exception
from evaluation.utility.document import EvaluationWrapperBase, Document, Result
from evaluation.utility.asap_inference import get_inference_for_document
from evaluation.utility.helpers import logger

class EvaluationWrapper(EvaluationWrapperBase):

    def evaluate(self, document: Document) -> List[Result]:
        output = []
        result = get_inference_for_document(document, self.inference_model_name, "exception", self.local_mode, self.page_limit)
        logger.info(
            "Exception check complete. Performing related evaluations."
        )
        document.ai_exception = result
        # # @todo abstract this.
        # # @todo results could be created from a factory to prevent all the extra setting here.
        result = evaluate_archival_exception(
            self.branch_name, self.commit_sha, document
        )
        result.inference_model = self.inference_model_name
        output.append(dict(result))
        # logger.info("Calculating Rouge score.")
        # result.evaluation_model = self.evaluation_model.model_name
        # result.inference_model = self.inference_model_name
        # output.append(dict(result))
        # result = calculate_rouge_score(
        #     self.branch_name, self.commit_sha, document
        # )
        # logger.info("Evaluation complete.")
        # result.inference_model = self.inference_model_name
        # output.append(dict(result))
        return output
