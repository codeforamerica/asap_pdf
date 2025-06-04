import evaluate
from evaluation.utility.schema import Document

"""
Provides a BertScore metric. Not currently ready for production use.
"""

METRIC_VERSION = 1


def calculate_bert_score(document: Document) -> tuple[float, dict]:
    metric = evaluate.load("bertscore")
    metric_result = metric.compute(
        references=[document.human_summary],
        predictions=[document.ai_summary],
        model_type="distilbert-base-uncased",
    )
    metric_result.pop("hashcode", None)
    return metric_result["f1"][0], metric_result
