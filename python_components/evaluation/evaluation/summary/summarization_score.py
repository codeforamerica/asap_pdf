import asyncio
from typing import Union

from deepeval.metrics import BaseMetric
from deepeval.metrics.faithfulness.schema import *  # noqa F403
from deepeval.metrics.indicator import metric_progress_indicator
from deepeval.metrics.multimodal_metrics.multimodal_faithfulness.template import (
    MultimodalFaithfulnessTemplate,
)
from deepeval.metrics.summarization.schema import *  # noqa F403
from deepeval.metrics.utils import (
    check_mllm_test_case_params,
    construct_verbose_logs,
    initialize_multimodal_model,
    trimAndLoadJson,
)
from deepeval.models import DeepEvalBaseMLLM
from deepeval.test_case import (
    MLLMImage,
    MLLMTestCase,
    MLLMTestCaseParams,
)
from deepeval.utils import get_or_create_event_loop, prettify_list
from evaluation.summary.summarization_template import MLLMSummarizationTemplate

METRIC_VERSION = 2


class MultimodalInputSummarization(BaseMetric):

    _required_params: List[MLLMTestCaseParams] = [
        MLLMTestCaseParams.INPUT,
        MLLMTestCaseParams.ACTUAL_OUTPUT,
    ]

    def __init__(
        self,
        threshold: float = 0.5,
        n: int = 5,
        model: Optional[Union[str, DeepEvalBaseMLLM]] = None,
        assessment_questions: Optional[List[str]] = None,
        include_reason: bool = True,
        async_mode=True,
        strict_mode: bool = False,
        verbose_mode: bool = False,
        truths_extraction_limit: Optional[int] = None,
    ):
        self.threshold = 1 if strict_mode else threshold
        self.model, self.using_native_model = initialize_multimodal_model(model)
        self.evaluation_model = self.model.get_model_name()

        if assessment_questions is not None and len(assessment_questions) == 0:
            self.assessment_questions = None
        else:
            self.assessment_questions = assessment_questions

        self.include_reason = include_reason
        self.n = n
        self.async_mode = async_mode
        self.strict_mode = strict_mode
        self.verbose_mode = verbose_mode

        self.truths_extraction_limit = truths_extraction_limit
        if self.truths_extraction_limit is not None:
            self.truths_extraction_limit = max(self.truths_extraction_limit, 0)

    def measure(
        self,
        test_case: MLLMTestCase,
        _show_indicator: bool = True,
    ) -> float:
        check_mllm_test_case_params(test_case, self._required_params, None, None, self)
        self.evaluation_cost = 0 if self.using_native_model else None
        with metric_progress_indicator(self, _show_indicator=_show_indicator):
            if self.async_mode:
                loop = get_or_create_event_loop()
                loop.run_until_complete(
                    self.a_measure(test_case, _show_indicator=False)
                )
            else:
                self.truths: List[str] = self._generate_truths(test_case.input)
                self.claims: List[str] = self._generate_claims(test_case.actual_output)
                self.coverage_verdicts: List[SummarizationCoverageVerdict] = (
                    self._generate_coverage_verdicts(test_case)
                )
                self.alignment_verdicts: List[SummarizationAlignmentVerdict] = (
                    self._generate_alignment_verdicts()
                )
                alignment_score = self._calculate_score(ScoreType.ALIGNMENT)
                coverage_score = self._calculate_score(ScoreType.COVERAGE)
                self.score_breakdown = {
                    ScoreType.ALIGNMENT.value: alignment_score,
                    ScoreType.COVERAGE.value: coverage_score,
                }
                self.score = min(alignment_score, coverage_score)
                self.success = self.score >= self.threshold
                self.verbose_logs = construct_verbose_logs(
                    self,
                    steps=[
                        f"Truths (limit={self.truths_extraction_limit}):\n{prettify_list(self.truths)}",
                        f"Claims:\n{prettify_list(self.claims)}",
                        f"Assessment Questions:\n{prettify_list(self.assessment_questions)}",
                        f"Coverage Verdicts:\n{prettify_list(self.coverage_verdicts)}",
                        f"Alignment Verdicts:\n{prettify_list(self.alignment_verdicts)}",
                        f"Score: {self.score}\nReason: {self.reason}",
                    ],
                )

            return self.score

    async def a_measure(
        self,
        test_case: MLLMTestCase,
        _show_indicator: bool = True,
    ) -> float:
        check_mllm_test_case_params(test_case, self._required_params, None, None, self)
        self.evaluation_cost = 0 if self.using_native_model else None
        with metric_progress_indicator(
            self,
            async_mode=True,
            _show_indicator=_show_indicator,
        ):
            self.truths, self.claims = await asyncio.gather(
                self._a_generate_truths(test_case.input),
                self._a_generate_claims(test_case.actual_output),
            )
            (
                self.coverage_verdicts,
                self.alignment_verdicts,
            ) = await asyncio.gather(
                self._a_generate_coverage_verdicts(test_case),
                self._a_generate_alignment_verdicts(),
            )
            alignment_score = self._calculate_score(ScoreType.ALIGNMENT)
            coverage_score = self._calculate_score(ScoreType.COVERAGE)
            self.score_breakdown = {
                ScoreType.ALIGNMENT.value: alignment_score,
                ScoreType.COVERAGE.value: coverage_score,
            }
            self.score = min(alignment_score, coverage_score)
            self.success = self.score >= self.threshold
            self.verbose_logs = construct_verbose_logs(
                self,
                steps=[
                    f"Truths (limit={self.truths_extraction_limit}):\n{prettify_list(self.truths)}",
                    f"Claims:\n{prettify_list(self.claims)}",
                    f"Assessment Questions:\n{prettify_list(self.assessment_questions)}",
                    f"Coverage Verdicts:\n{prettify_list(self.coverage_verdicts)}",
                    f"Alignment Verdicts:\n{prettify_list(self.alignment_verdicts)}",
                    f"Score: {self.score}\nReason: {self.reason}",
                ],
            )
            return self.score

    def _calculate_score(self, score_type: ScoreType) -> float:
        if score_type == ScoreType.ALIGNMENT:
            total = len(self.alignment_verdicts)
            if total == 0:
                return 0
            faithfulness_count = 0
            for verdict in self.alignment_verdicts:
                # Different from the faithfulness score, this
                # penalizes 'idk' (full of fluff) summaries
                if verdict.verdict.strip().lower() == "yes":
                    faithfulness_count += 1

            score = faithfulness_count / total

        else:
            if self.assessment_questions is None:
                return 1
            total = 0
            coverage_count = 0
            for verdict in self.coverage_verdicts:
                if verdict.original_verdict.strip().lower() == "yes":
                    total += 1
                    if verdict.summary_verdict.strip().lower() == "yes":
                        coverage_count += 1

            if total == 0:
                return 0

            score = coverage_count / total

        return 0 if self.strict_mode and score < self.threshold else score

    async def _a_generate_answers(self, input: str | list[MLLMImage]) -> List[str]:
        prompt = MLLMSummarizationTemplate.generate_answers(
            questions=self.assessment_questions,
            input=input,
        )
        if self.using_native_model:
            res, cost = await self.model.a_generate(prompt, schema=Answers)
            self.evaluation_cost += cost
            return res.answers
        else:
            try:
                res: Answers = await self.model.a_generate(prompt, schema=Answers)
                return res.answers
            except TypeError:
                res = await self.model.a_generate(prompt)
                data = trimAndLoadJson(res, self)
                return data["answers"]

    def _generate_answers(self, text: str) -> List[str]:
        prompt = MLLMSummarizationTemplate.generate_answers(
            questions=self.assessment_questions, text=text
        )
        if self.using_native_model:
            res, cost = self.model.generate(prompt, schema=Answers)
            self.evaluation_cost += cost
            return res.answers
        else:
            try:
                res: Answers = self.model.generate(prompt, schema=Answers)
                return res.answers
            except TypeError:
                res = self.model.generate(prompt)
                data = trimAndLoadJson(res, self)
                return data["answers"]

    async def _a_generate_assessment_questions(self, images: list[MLLMImage]):
        prompt = MLLMSummarizationTemplate.generate_questions(n=self.n)
        prompt = [prompt] + images
        if self.using_native_model:
            res, cost = await self.model.a_generate(prompt, schema=Questions)
            self.evaluation_cost += cost
            return res.questions
        else:
            try:
                res: Questions = await self.model.a_generate(prompt, schema=Questions)
                return res.questions
            except TypeError:
                res = await self.model.a_generate(prompt)
                data = trimAndLoadJson(res, self)
                return data["questions"]

    def _generate_assessment_questions(self, images: list[MLLMImage]):
        prompt = MLLMSummarizationTemplate.generate_questions(n=self.n)
        prompt = [prompt] + images
        if self.using_native_model:
            res, cost = self.model.generate(prompt, schema=Questions)
            self.evaluation_cost += cost
            return res.questions
        else:
            try:
                res: Questions = self.model.generate(prompt, schema=Questions)
                return res.questions
            except TypeError:
                res = self.model.generate(prompt)
                data = trimAndLoadJson(res, self)
                return data["questions"]

    async def _a_generate_coverage_verdicts(
        self, test_case: MLLMTestCase
    ) -> List[SummarizationCoverageVerdict]:
        if self.assessment_questions is None:
            self.assessment_questions = await self._a_generate_assessment_questions(
                test_case.input
            )
        tasks = [
            self._a_generate_answers(test_case.input),
            self._a_generate_answers(test_case.actual_output),
        ]
        results = await asyncio.gather(*tasks)
        original_answers = results[0]
        summary_answers = results[1]

        if len(original_answers) != len(summary_answers):
            raise ValueError("Number of verdicts generated does not equal.")

        coverage_verdicts: List[SummarizationCoverageVerdict] = []
        for i in range(len(original_answers)):
            coverage_verdicts.append(
                SummarizationCoverageVerdict(
                    summary_verdict=summary_answers[i],
                    original_verdict=original_answers[i],
                    question=self.assessment_questions[i],
                )
            )
        return coverage_verdicts

    def _generate_coverage_verdicts(
        self, test_case: MLLMTestCase
    ) -> List[SummarizationCoverageVerdict]:
        if self.assessment_questions is None:
            self.assessment_questions = self._generate_assessment_questions(
                test_case.input
            )

        original_answers = self._generate_answers(test_case.input)
        summary_answers = self._generate_answers(test_case.actual_output)

        if len(original_answers) != len(summary_answers):
            raise ValueError("Number of verdicts generated does not equal.")

        coverage_veridcts: List[SummarizationCoverageVerdict] = []
        for i in range(len(original_answers)):
            coverage_veridcts.append(
                SummarizationCoverageVerdict(
                    summary_verdict=summary_answers[i],
                    original_verdict=original_answers[i],
                    question=self.assessment_questions[i],
                )
            )

        return coverage_veridcts

    async def _a_generate_alignment_verdicts(
        self,
    ) -> List[SummarizationAlignmentVerdict]:
        if len(self.claims) == 0:
            return []

        verdicts: List[SummarizationAlignmentVerdict] = []
        prompt = MLLMSummarizationTemplate.generate_alignment_verdicts(
            summary_claims=self.claims, orignal_text="\n\n".join(self.truths)
        )
        if self.using_native_model:
            res, cost = await self.model.a_generate(prompt, schema=Verdicts)
            self.evaluation_cost += cost
            verdicts = [item for item in res.verdicts]
            return verdicts
        else:
            try:
                res: Verdicts = await self.model.a_generate(prompt, schema=Verdicts)
                verdicts = [item for item in res.verdicts]
                return verdicts
            except TypeError:
                res = await self.model.a_generate(prompt)
                data = trimAndLoadJson(res, self)
                verdicts = [
                    SummarizationAlignmentVerdict(**item) for item in data["verdicts"]
                ]
                return verdicts

    def _generate_alignment_verdicts(
        self,
    ) -> List[SummarizationAlignmentVerdict]:
        if len(self.claims) == 0:
            return []

        verdicts: List[SummarizationAlignmentVerdict] = []
        prompt = MLLMSummarizationTemplate.generate_alignment_verdicts(
            summary_claims=self.claims, orignal_text="\n\n".join(self.truths)
        )
        if self.using_native_model:
            res, cost = self.model.generate(prompt, schema=Verdicts)
            self.evaluation_cost += cost
            verdicts = [item for item in res.verdicts]
            return verdicts
        else:
            try:
                res: Verdicts = self.model.generate(prompt, schema=Verdicts)
                verdicts = [item for item in res.verdicts]
                return verdicts
            except TypeError:
                res = self.model.generate(prompt)
                data = trimAndLoadJson(res, self)
                verdicts = [
                    SummarizationAlignmentVerdict(**item) for item in data["verdicts"]
                ]
                return verdicts

    async def _a_generate_truths(self, images: list[MLLMImage]) -> List[str]:
        # Borrow faithfulness template
        prompt = MultimodalFaithfulnessTemplate.generate_truths(
            images,
            extraction_limit=self.truths_extraction_limit,
        )
        if self.using_native_model:
            res, cost = await self.model.a_generate(prompt, schema=Truths)
            self.evaluation_cost += cost
            return res.truths
        else:
            try:
                res: Truths = await self.model.a_generate(prompt, schema=Truths)
                return res.truths
            except TypeError:
                res = await self.model.a_generate(prompt)
                data = trimAndLoadJson(res, self)
                return data["truths"]

    def _generate_truths(self, images: list[MLLMImage]) -> List[str]:
        # Borrow faithfulness template
        prompt = MultimodalFaithfulnessTemplate.generate_truths(
            images,
            extraction_limit=self.truths_extraction_limit,
        )
        if self.using_native_model:
            res, cost = self.model.generate(prompt, schema=Truths)
            self.evaluation_cost += cost
            return res.truths
        else:
            try:
                res: Truths = self.model.generate(prompt, schema=Truths)
                return res.truths
            except TypeError:
                res = self.model.generate(prompt)
                data = trimAndLoadJson(res, self)
                return data["truths"]

    async def _a_generate_claims(self, text: str) -> List[str]:
        # Borrow faithfulness template
        prompt = MultimodalFaithfulnessTemplate.generate_claims([text])
        if self.using_native_model:
            res, cost = await self.model.a_generate(prompt, schema=Claims)
            self.evaluation_cost += cost
            return res.claims
        else:
            try:
                res: Claims = await self.model.a_generate(prompt, schema=Claims)
                return res.claims
            except TypeError:
                res = await self.model.a_generate(prompt)
                data = trimAndLoadJson(res, self)
                return data["claims"]

    def _generate_claims(self, text: str) -> List[str]:
        # Borrow faithfulness template
        prompt = MultimodalFaithfulnessTemplate.generate_claims([text])
        if self.using_native_model:
            res, cost = self.model.generate(prompt, schema=Claims)
            self.evaluation_cost += cost
            return res.claims
        else:
            try:
                res: Claims = self.model.generate(prompt, schema=Claims)
                return res.claims
            except TypeError:
                res = self.model.generate(prompt)
                data = trimAndLoadJson(res, self)
                return data["claims"]

    def is_successful(self) -> bool:
        if self.error is not None:
            self.success = False
        else:
            try:
                self.success = self.score >= self.threshold
            except:  # noqa E722
                self.success = False
        return self.success

    @property
    def __name__(self):
        return "Image Input to Text Summarization"
