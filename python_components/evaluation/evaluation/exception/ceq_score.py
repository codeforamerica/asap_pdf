from typing import List, Optional, Type, Union

from deepeval.metrics import BaseMetric
from deepeval.metrics.indicator import metric_progress_indicator
from deepeval.metrics.utils import (
    check_llm_test_case_params,
    construct_verbose_logs,
    initialize_multimodal_model,
    trimAndLoadJson,
)
from deepeval.models import DeepEvalBaseLLM
from deepeval.test_case import (
    LLMTestCase,
    LLMTestCaseParams,
)
from deepeval.utils import get_or_create_event_loop, prettify_list
from evaluation.exception.ceq_schema import CEQVerdict, Verdicts
from evaluation.exception.ceq_template import CEQTemplate


class CloseEndedQuestionsMetric(BaseMetric):
    _required_params: List[LLMTestCaseParams] = [
        LLMTestCaseParams.INPUT,
        LLMTestCaseParams.ACTUAL_OUTPUT,
        LLMTestCaseParams.RETRIEVAL_CONTEXT,
    ]

    def __init__(
        self,
        assessment_questions: List,
        threshold: float = 0.5,
        model: Optional[Union[str, DeepEvalBaseLLM]] = None,
        include_reason: bool = True,
        async_mode: bool = True,
        strict_mode: bool = False,
        verbose_mode: bool = False,
        evaluation_template: Type[CEQTemplate] = CEQTemplate,
    ):
        self.threshold = 1 if strict_mode else threshold
        self.model, self.using_native_model = initialize_multimodal_model(model)
        self.evaluation_model = self.model.get_model_name()
        self.include_reason = include_reason
        self.async_mode = async_mode
        self.strict_mode = strict_mode
        self.verbose_mode = verbose_mode
        self.evaluation_template = evaluation_template
        self.assessment_questions = assessment_questions

    def measure(
        self,
        test_case: LLMTestCase,
        _show_indicator: bool = True,
        _in_component: bool = False,
    ) -> float:
        check_llm_test_case_params(test_case, self._required_params, self)
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
                self.verdicts = self._generate_verdicts(
                    test_case.input,
                    test_case.actual_output,
                    test_case.retrieval_context,
                )
                self.score = self._calculate_score()
                self.success = self.score >= self.threshold
                self.verbose_logs = construct_verbose_logs(
                    self,
                    steps=[
                        f"Verdicts:\n{prettify_list(self.verdicts)}",
                        f"Score: {self.score}\nReason: {self.reason}",
                    ],
                )
            return self.score

    async def a_measure(
        self,
        test_case: LLMTestCase,
        _show_indicator: bool = True,
        _in_component: bool = False,
    ) -> float:
        check_llm_test_case_params(test_case, self._required_params, self)
        self.evaluation_cost = 0 if self.using_native_model else None
        with metric_progress_indicator(
            self,
            async_mode=True,
            _show_indicator=_show_indicator,
            _in_component=_in_component,
        ):
            self.verdicts = self._generate_verdicts(
                test_case.input, test_case.actual_output, test_case.retrieval_context
            )
            self.score = self._calculate_score()
            self.success = self.score >= self.threshold
            self.verbose_logs = construct_verbose_logs(
                self,
                steps=[
                    f"Verdicts:\n{prettify_list(self.verdicts)}",
                    f"Score: {self.score}\nReason: {self.reason}",
                ],
            )
            return self.score

    def _generate_verdicts(
        self, input: str, actual_output: str, retrieval_context: Optional[str]
    ) -> List[CEQVerdict]:
        verdicts: List[CEQVerdict] = []
        prompt = self.evaluation_template.get_verdicts(
            input, actual_output, self.assessment_questions, retrieval_context
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
                verdicts = [CEQVerdict(**item) for item in data["verdicts"]]
                return verdicts

    def _calculate_score(self) -> float:
        yes_scores = 0
        for verdict in self.verdicts:
            if verdict.verdict == "yes":
                yes_scores += 1
        return yes_scores / len(self.verdicts)

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
        return "Multi Modal Close Ended Questions"
