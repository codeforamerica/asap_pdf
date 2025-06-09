import asyncio
from typing import List, Optional, Type, Union

from deepeval.metrics import BaseMetric
from deepeval.metrics.faithfulness.schema import (
    Claims,
    FaithfulnessVerdict,
    Truths,
    Verdicts,
)
from deepeval.metrics.indicator import metric_progress_indicator
from deepeval.metrics.utils import (
    check_mllm_test_case_params,
    construct_verbose_logs,
    initialize_multimodal_model,
    trimAndLoadJson,
)
from deepeval.models import DeepEvalBaseMLLM
from deepeval.test_case import (
    ConversationalTestCase,
    MLLMImage,
    MLLMTestCase,
    MLLMTestCaseParams,
)
from deepeval.utils import get_or_create_event_loop, prettify_list
from evaluation.utility.faithfulness_template import MllMInputFaithfulnessTemplate

METRIC_VERSION = 1


class MultiModalFaithfulnessMetric(BaseMetric):
    _required_params: List[MLLMTestCaseParams] = [
        MLLMTestCaseParams.INPUT,
        MLLMTestCaseParams.ACTUAL_OUTPUT,
        MLLMTestCaseParams.RETRIEVAL_CONTEXT,
    ]

    def __init__(
        self,
        threshold: float = 0.5,
        model: Optional[Union[str, DeepEvalBaseMLLM]] = None,
        include_reason: bool = True,
        async_mode: bool = True,
        strict_mode: bool = False,
        verbose_mode: bool = False,
        truths_extraction_limit: Optional[int] = None,
        evaluation_template: Type[
            MllMInputFaithfulnessTemplate
        ] = MllMInputFaithfulnessTemplate,
    ):
        self.threshold = 1 if strict_mode else threshold
        self.model, self.using_native_model = initialize_multimodal_model(model)
        self.evaluation_model = self.model.get_model_name()
        self.include_reason = include_reason
        self.async_mode = async_mode
        self.strict_mode = strict_mode
        self.verbose_mode = verbose_mode
        self.evaluation_template = evaluation_template

        self.truths_extraction_limit = truths_extraction_limit
        if self.truths_extraction_limit is not None:
            self.truths_extraction_limit = max(self.truths_extraction_limit, 0)

    def measure(
        self,
        test_case: Union[MLLMTestCase, ConversationalTestCase],
        _show_indicator: bool = True,
        _in_component: bool = False,
    ) -> float:
        if isinstance(test_case, ConversationalTestCase):
            test_case = test_case.turns[-1]
        check_mllm_test_case_params(test_case, self._required_params, None, None, self)

        self.evaluation_cost = 0 if self.using_native_model else None
        with metric_progress_indicator(
            self, _show_indicator=_show_indicator, _in_component=_in_component
        ):
            if self.async_mode:
                loop = get_or_create_event_loop()
                loop.run_until_complete(
                    self.a_measure(
                        test_case,
                        _show_indicator=False,
                        _in_component=_in_component,
                    )
                )
            else:
                self.truths = self._generate_truths(test_case.retrieval_context)
                self.claims = self._generate_claims(test_case.actual_output)
                self.verdicts = self._generate_verdicts()
                self.score = self._calculate_score()
                self.success = self.score >= self.threshold
                self.verbose_logs = construct_verbose_logs(
                    self,
                    steps=[
                        f"Truths (limit={self.truths_extraction_limit}):\n{prettify_list(self.truths)}",
                        f"Claims:\n{prettify_list(self.claims)}",
                        f"Verdicts:\n{prettify_list(self.verdicts)}",
                        f"Score: {self.score}\nReason: {self.reason}",
                    ],
                )

            return self.score

    async def a_measure(
        self,
        test_case: Union[MLLMTestCase, ConversationalTestCase],
        _show_indicator: bool = True,
        _in_component: bool = False,
    ) -> float:
        if isinstance(test_case, ConversationalTestCase):
            test_case = test_case.turns[-1]
        check_mllm_test_case_params(test_case, self._required_params, None, None, self)
        self.evaluation_cost = 0 if self.using_native_model else None
        with metric_progress_indicator(
            self,
            async_mode=True,
            _show_indicator=_show_indicator,
            _in_component=_in_component,
        ):
            self.truths, self.claims = await asyncio.gather(
                self._a_generate_truths(test_case.retrieval_context),
                self._a_generate_claims(test_case.actual_output),
            )
            self.verdicts = await self._a_generate_verdicts()
            self.score = self._calculate_score()
            self.success = self.score >= self.threshold
            self.verbose_logs = construct_verbose_logs(
                self,
                steps=[
                    f"Truths (limit={self.truths_extraction_limit}):\n{prettify_list(self.truths)}",
                    f"Claims:\n{prettify_list(self.claims)}",
                    f"Verdicts:\n{prettify_list(self.verdicts)}",
                    f"Score: {self.score}\nReason: {self.reason}",
                ],
            )

            return self.score

    async def _a_generate_verdicts(self) -> List[FaithfulnessVerdict]:
        if len(self.claims) == 0:
            return []

        verdicts: List[FaithfulnessVerdict] = []
        prompt = self.evaluation_template.generate_verdicts(
            claims=self.claims, retrieval_context="\n\n".join(self.truths)
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
                verdicts = [FaithfulnessVerdict(**item) for item in data["verdicts"]]
                return verdicts

    def _generate_verdicts(self) -> List[FaithfulnessVerdict]:
        if len(self.claims) == 0:
            return []

        verdicts: List[FaithfulnessVerdict] = []
        prompt = self.evaluation_template.generate_verdicts(
            claims=self.claims, retrieval_context="\n\n".join(self.truths)
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
                verdicts = [FaithfulnessVerdict(**item) for item in data["verdicts"]]
                return verdicts

    async def _a_generate_truths(
        self, retrieval_context: List[str | MLLMImage]
    ) -> List[str]:
        prompt = self.evaluation_template.generate_truths(
            retrieval_context=retrieval_context,
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

    def _generate_truths(self, retrieval_context: List[str | MLLMImage]) -> List[str]:
        prompt = self.evaluation_template.generate_truths(
            retrieval_context=retrieval_context,
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

    async def _a_generate_claims(self, actual_output: str) -> List[str]:
        prompt = self.evaluation_template.generate_claims(actual_output=actual_output)
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

    def _generate_claims(self, actual_output: str) -> List[str]:
        prompt = self.evaluation_template.generate_claims(actual_output=actual_output)
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

    def _calculate_score(self) -> float:
        number_of_verdicts = len(self.verdicts)
        if number_of_verdicts == 0:
            return 1

        faithfulness_count = 0
        for verdict in self.verdicts:
            if verdict.verdict.strip().lower() != "no":
                faithfulness_count += 1

        score = faithfulness_count / number_of_verdicts
        return 0 if self.strict_mode and score < self.threshold else score

    def is_successful(self) -> bool:
        if self.error is not None:
            self.success = False
        else:
            try:
                self.success = self.score >= self.threshold
            except TypeError:
                self.success = False
        return self.success

    @property
    def __name__(self):
        return "MLLM Faithfulness"
