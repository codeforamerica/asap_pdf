import asyncio
from typing import List

from deepeval.test_case import (
    LLMTestCase,
    MLLMTestCase,
)
from evaluation.exception.ceq_score import METRIC_VERSION as CEQ_VERSION
from evaluation.exception.ceq_score import CloseEndedQuestionsMetric
from evaluation.exception.deterministic_score import (
    METRIC_VERSION as DETERMINISTIC_VERSION,
)
from evaluation.exception.deterministic_score import (
    evaluate_archival_exception,
    evaluate_application_exception,
)
from evaluation.exception.faithfulness_score import (
    METRIC_VERSION as FAITHFULNESS_VERSION,
)
from evaluation.exception.faithfulness_score import (
    MultiModalFaithfulnessMetric,
)
from evaluation.utility.asap_inference import get_inference_for_document
from evaluation.utility.document import EvaluationWrapperBase, convert_model_list
from evaluation.utility.helpers import logger
from evaluation.utility.schema import Document, Result

ARCHIVE_EXCEPTION_CONTEXT = [
    "An ADA rule exempts archived web content from accessibility requirements if it meets all four criteria: the content was created before the compliance deadline (April 2026) or reproduces pre-compliance physical documents, it's kept only for reference/research/recordkeeping purposes, it's stored in a designated archive area, and it's remained completely unchanged since being archived. All four conditions must be satisfied simultaneously for the exception to apply."
]
ARCHIVE_EXCEPTION_CEQ = [
    'Does the "Reason Text" include the same date as the document metadata value for "Creation Date"?',
    'Does the "Reason Text" include information about whether the document is stored in a special archival section of the website?',
    'Does the "Reason Text" include information about whether the document is kept only for reference?',
    'Does the "Reason Text" suggest the same archival status as the "Qualifies as Archival" document metadata value?',
]

APPLICATION_EXCEPTION_CONTEXT = [
    "An ADA rule exempts prexisting conventional electronic documents from accessibility requirements if it meets all three criteria: the document is a PDF file, content was available on the government's website or mobile app before the compliance date (April 2026), and the document is not currently being used by individuals to apply for, access, or participate in government services. All three conditions must be satisfied simultaneously for the exception to apply."
]
APPLICATION_EXCEPTION_CEQ = [
    'Does the "Reason Text" include information about whether the document could be currently used to apply for, access, or participate in a state or local government services, programs, or activities?',
    'Does the "Reason Text" suggest the same application status as the "Qualifies as Application" document metadata value?',
]

class EvaluationWrapper(EvaluationWrapperBase):

    async def evaluate(self, document: Document) -> List[Result]:
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
        tasks = [
            self._deterministic_evaluate(document, "archival"),
            self._deterministic_evaluate(document, "application"),
        ]
        results = await asyncio.gather(*tasks)
        for result in results:
            output.append(dict(result))

        # Perform close ended questions evaluation.
        logger.info("Beginning CEQ evaluation...")
        tasks = [
            self._ceq_evaluate(document, "archival"),
            self._ceq_evaluate(document, "application"),
        ]
        results = await asyncio.gather(*tasks)
        for result in results:
            output.append(dict(result))

        # Perform faithfulness evaluation.
        logger.info("Beginning Faithfulness evaluation...")
        tasks = [
            self._faithfulness_evaluate(document, "archival"),
            self._faithfulness_evaluate(document, "application"),
        ]
        results = await asyncio.gather(*tasks)
        for result in results:
            output.append(dict(result))

        logger.info("Evaluation complete.")
        return output

    async def _deterministic_evaluate(self, document, exception) -> Result:
        if exception == "archival":
            score, details = evaluate_archival_exception(document)
            response = document.ai_exception["why_archival"]
        elif exception == "application":
            score, details = evaluate_application_exception(document)
            response = document.ai_exception["why_application"]

        details["response"] = response
        return self.result_factory.new(
            {
                "metric_name": f"deterministic:{exception}",
                "metric_version": DETERMINISTIC_VERSION,
                "score": score,
                "details": details,
                "file_name": document.file_name,
                "inference_model": self.inference_model_name,
                "evaluation_model": self.evaluation_model.model_name,
            }
        )

    async def _ceq_evaluate(self, document, exception) -> Result:
        if exception == "archival":
            questions = ARCHIVE_EXCEPTION_CEQ
            decision = f"Qualifies as Archival: {document.human_exception["is_archival"]}"
            response = document.ai_exception["why_archival"]
            context = ARCHIVE_EXCEPTION_CONTEXT
        elif exception == "application":
            questions = APPLICATION_EXCEPTION_CEQ
            decision = f"Qualifies as Application: {document.human_exception["is_application"]}"
            response = document.ai_exception["why_application"]
            context = APPLICATION_EXCEPTION_CONTEXT

        metric = CloseEndedQuestionsMetric(
            model=self.evaluation_model, assessment_questions=questions
        )
        details = document.llm_context()
        details.append(decision)
        test_case = LLMTestCase(
            actual_output=[response],
            retrieval_context=context,
            input="\n\n".join(details),
        )
        metric.measure(test_case)
        details = {
            "verdicts": convert_model_list(metric.verdicts),
            "response": response,
        }
        logger.info(f"CEQ evaluation of {exception} complete.")
        return self.result_factory.new(
            {
                "metric_name": f"deepeval_llm_ceq:{exception}",
                "metric_version": CEQ_VERSION,
                "score": metric.score,
                "reason": metric.reason,
                "details": details,
                "file_name": document.file_name,
                "inference_model": self.inference_model_name,
                "evaluation_model": self.evaluation_model.model_name,
            }
        )

    async def _faithfulness_evaluate(self, document, exception):
        if exception == "archival":
            response = document.ai_exception["why_archival"]
            context = ARCHIVE_EXCEPTION_CONTEXT
        elif exception == "application":
            response = document.ai_exception["why_application"]
            context = APPLICATION_EXCEPTION_CONTEXT

        metric = MultiModalFaithfulnessMetric(model=self.evaluation_model)
        test_case = MLLMTestCase(
            input=[],
            retrieval_context=context + document.images,
            actual_output=[response],
        )
        metric.measure(test_case)
        details = {
            "truths": metric.truths,
            "claims": metric.claims,
            "verdicts": convert_model_list(metric.verdicts),
            "response": response,
        }
        logger.info(f"Faithfulness evaluation of {exception} complete.")
        return self.result_factory.new(
            {
                "metric_name": f"deepeval_mllm_faithfulness:{exception}",
                "metric_version": FAITHFULNESS_VERSION,
                "score": metric.score,
                "reason": metric.reason,
                "details": details,
                "file_name": document.file_name,
                "inference_model": self.inference_model_name,
                "evaluation_model": self.evaluation_model.model_name,
            }
        )
