import evaluate
import numpy as np
from evaluation.utility.document import Document, Result


def calculate_rouge_score(
    branch_name: str,
    commit_sha: str,
    document: Document,
) -> Result:
    metric = evaluate.load("rouge")
    metric_result = metric.compute(
        references=[document.human_summary], predictions=[document.ai_summary]
    )
    for key, value in metric_result.items():
        if type(value) is np.float64:
            metric_result[key] = float(value)
    return Result(
        branch_name=branch_name,
        commit_sha=commit_sha,
        file_name=document.file_name,
        metric_name="rouge_score",
        score=metric_result["rougeLsum"],
        details=metric_result,
    )
