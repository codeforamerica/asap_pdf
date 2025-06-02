from typing import List

from evaluation.exception.deterministic_score import evaluate_archival_exception
from evaluation.exception.faithfulness_score import evaluate_faithfulness
from evaluation.exception.ceq_score import evaluate_ceq
from evaluation.utility.document import EvaluationWrapperBase, Document, Result
from evaluation.utility.asap_inference import get_inference_for_document
from evaluation.utility.helpers import logger

ARCHIVE_EXCEPTION_CONTEXT = ["An ADA rule exempts archived web content from accessibility requirements if it meets all four criteria: the content was created before the compliance deadline (April, 2026) or reproduces pre-compliance physical documents, it's kept only for reference/research/recordkeeping purposes, and it's stored in a designated archive area. The content must also remain completely unchanged since being archived. All four conditions must be satisfied simultaneously for the exemption to apply."]

ARCHIVE_EXCEPTION_CEQ = [
    'Does the "Reason Text" include the same date as the document metadata value for "Creation Date"?',
    'Does the "Reason Text" include information about whether the document is stored in a special archival section of the website?',
    'Does the "Reason Text" include information about whether the document is kept only for reference?',
    'Does the "Reason Text" suggest the same archival status as the "Qualifies as Archival" document metadata value?',
]

class EvaluationWrapper(EvaluationWrapperBase):

    def evaluate(self, document: Document) -> List[Result]:
        output = []
        result = get_inference_for_document(document, self.inference_model_name, "exception", self.local_mode, self.page_limit)
        logger.info(
            "Exception check complete. Performing related evaluations."
        )
        document.ai_exception = result
        # @todo abstract this.
        # @todo results could be created from a factory to prevent all the extra setting here.
        logger.info(f"Beginning deterministic evaluation...")
        result = evaluate_archival_exception(
            self.branch_name, self.commit_sha, document
        )
        result.inference_model = self.inference_model_name
        output.append(dict(result))
        logger.info(f"Beginning CEQ evaluation...")
        result = evaluate_ceq(
            self.branch_name,
            self.commit_sha,
            document,
            self.evaluation_model,
            ARCHIVE_EXCEPTION_CEQ,
            document.ai_exception["why_archival"],
            ARCHIVE_EXCEPTION_CONTEXT
        )
        result.metric_name = f"{result.metric_name}:archival"
        result.evaluation_model = self.evaluation_model.model_name
        result.inference_model = self.inference_model_name
        output.append(dict(result))
        result = evaluate_faithfulness(
            self.branch_name,
            self.commit_sha,
            document,
            self.evaluation_model,
            ARCHIVE_EXCEPTION_CONTEXT,
            document.ai_exception["why_archival"],
        )
        result.metric_name = f"{result.metric_name}:archival"
        result.evaluation_model = self.evaluation_model.model_name
        result.inference_model = self.inference_model_name
        output.append(dict(result))
        return output
