import evaluate

from evaluation.utility.document import Document, Result
from evaluation.utility.helpers import logger


def calculate_bert_score(branch_name: str,
                             commit_sha: str,
                             document: Document,
                             ) -> Result:
    metric = evaluate.load("bertscore")
    metric_result = metric.compute(references=[document.human_summary], predictions=[document.ai_summary], model_type="distilbert-base-uncased")
    metric_result.pop("hashcode", None)
    return Result(
        branch_name=branch_name,
        commit_sha=commit_sha,
        file_name=document.file_name,
        metric_name="bert_score",
        score=metric_result["f1"][0],
        details=metric_result,
    )
