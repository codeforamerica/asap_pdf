import evaluate
import numpy as np
from evaluation.utility.document import Document


def calculate_rouge_score(document: Document) -> tuple[float, dict]:
    metric = evaluate.load("rouge")
    metric_result = metric.compute(
        references=[document.human_summary], predictions=[document.ai_summary]
    )
    for key, value in metric_result.items():
        if type(value) is np.float64:
            metric_result[key] = float(value)
    return metric_result["rougeLsum"], metric_result
