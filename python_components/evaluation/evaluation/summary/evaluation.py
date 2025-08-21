from typing import List

from deepeval.test_case import MLLMTestCase
from evaluation.summary.rouge_score import METRIC_VERSION as ROUGE_VERSION
from evaluation.summary.rouge_score import calculate_rouge_score
from evaluation.summary.summarization_score import (
    METRIC_VERSION as SUMMARIZATION_VERSION,
)
from evaluation.summary.summarization_score import (
    MultimodalInputSummarization,
)
from evaluation.utility.asap_inference import get_inference_for_document
from evaluation.utility.document import EvaluationWrapperBase, convert_model_list
from evaluation.utility.helpers import logger
from evaluation.utility.schema import Document, Result


class EvaluationWrapper(EvaluationWrapperBase):

    def evaluate(self, document: Document) -> List[Result]:
        output = []
        # Perform any inference required for evaluation.
        logger.info("Beginning summarization.")
        result = get_inference_for_document(
            document,
            self.inference_model_name,
            "summary",
            self.local_mode,
            self.aws_env,
            self.page_limit,
        )
        logger.info("Summarization complete. Performing related evaluations.")
        document.ai_summary = result["summary"]
        # Begin the DeepEval summary evaluation.
        metric = MultimodalInputSummarization(model=self.evaluation_model)
        test_case = MLLMTestCase(
            input=document.images, actual_output=document.ai_summary
        )
        metric.measure(test_case)
        details = {
            "truths": metric.truths,
            "claims": metric.claims,
            "assessment_questions": convert_model_list(metric.assessment_questions),
            "coverage_verdicts": convert_model_list(metric.coverage_verdicts),
            "alignment_verdicts": convert_model_list(metric.alignment_verdicts),
        }
        result = self.result_factory.new(
            {
                "metric_name": "deepeval_mllm_summary",
                "metric_version": SUMMARIZATION_VERSION,
                "score": metric.score,
                "reason": metric.reason,
                "details": details,
                "file_name": document.file_name,
            }
        )
        output.append(dict(result))
        # Calculate ROUGE score.
        logger.info("Calculating ROUGE score.")
        score, details = calculate_rouge_score(document)
        result = self.result_factory.new(
            {
                "metric_name": "rouge_score",
                "metric_version": ROUGE_VERSION,
                "score": score,
                "details": details,
                "file_name": document.file_name,
                "evaluation_model_name": None,
            }
        )
        logger.info("Evaluation complete.")
        result.inference_model = self.inference_model_name
        output.append(dict(result))
        return output
