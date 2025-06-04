from typing import List

from deepeval.test_case import (
    LLMTestCase,
    MLLMTestCase,
)
from evaluation.exception import deterministic_score
from evaluation.exception.ceq_score import CloseEndedQuestionsMetric
from evaluation.exception.faithfulness_score import MultiModalFaithfulnessMetric
from evaluation.utility.asap_inference import get_inference_for_document
from evaluation.utility.document import EvaluationWrapperBase, convert_model_list
from evaluation.utility.helpers import logger
from evaluation.utility.schema import Document, Result

ARCHIVE_EXCEPTION_CONTEXT = [
    "An ADA rule exempts archived web content from accessibility requirements if it meets all four criteria: the content was created before the compliance deadline (April, 2026) or reproduces pre-compliance physical documents, it's kept only for reference/research/recordkeeping purposes, and it's stored in a designated archive area. The content must also remain completely unchanged since being archived. All four conditions must be satisfied simultaneously for the exemption to apply."
]

ARCHIVE_EXCEPTION_CEQ = [
    'Does the "Reason Text" include the same date as the document metadata value for "Creation Date"?',
    'Does the "Reason Text" include information about whether the document is stored in a special archival section of the website?',
    'Does the "Reason Text" include information about whether the document is kept only for reference?',
    'Does the "Reason Text" suggest the same archival status as the "Qualifies as Archival" document metadata value?',
]


class EvaluationWrapper(EvaluationWrapperBase):

    def evaluate(self, document: Document) -> List[Result]:
        output = []
        # Perform inferences that we want to evaluate.
        result = get_inference_for_document(
            document,
            self.inference_model_name,
            "exception",
            self.local_mode,
            self.page_limit,
        )
        logger.info("Exception check complete. Performing related evaluations.")
        document.ai_exception = result
        # Perform deterministic evaluations.
        logger.info("Beginning deterministic evaluation...")
        score, details = deterministic_score.evaluate_archival_exception(document)
        result = self.result_factory.new(
            {
                "metric_name": "deterministic_archival_exception",
                "metric_version": 1,
                "score": score,
                "details": details,
                "file_name": document.file_name,
                "evaluation_model_name": None,
            }
        )
        output.append(dict(result))
        # Perform close ended questions evaluation.
        logger.info("Beginning CEQ evaluation...")
        metric = CloseEndedQuestionsMetric(
            model=self.evaluation_model, assessment_questions=ARCHIVE_EXCEPTION_CEQ
        )
        details = document.llm_context()
        details.append(
            f"Qualifies as Archival: {document.human_exception["is_archival"]}"
        )
        test_case = LLMTestCase(
            actual_output=[document.ai_exception["why_archival"]],
            retrieval_context=ARCHIVE_EXCEPTION_CONTEXT,
            input="\n\n".join(details),
        )
        metric.measure(test_case)
        result = self.result_factory.new(
            {
                "metric_name": "deepeval_llm_ceq:archival",
                "metric_version": 1,
                "score": metric.score,
                "details": {"verdicts": convert_model_list(metric.verdicts)},
                "file_name": document.file_name,
            }
        )
        output.append(dict(result))
        # Perform faithfulness evaluation.
        logger.info("Beginning Faithfulness evaluation...")
        metric = MultiModalFaithfulnessMetric(model=self.evaluation_model)
        test_case = MLLMTestCase(
            input=[],
            retrieval_context=ARCHIVE_EXCEPTION_CONTEXT + document.images,
            actual_output=[document.ai_exception["why_archival"]],
        )
        metric.measure(test_case)
        details = {
            "truths": metric.truths,
            "claims": metric.claims,
            "verdicts": convert_model_list(metric.verdicts),
        }
        result = self.result_factory.new(
            {
                "metric_name": "deepeval_mllm_faithfulness:archival",
                "metric_version": 1,
                "score": metric.score,
                "details": details,
                "file_name": document.file_name,
            }
        )
        output.append(dict(result))
        logger.info("Evaluation complete.")
        return output
