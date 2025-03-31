import argparse
import json

from deepeval import evaluate
from deepeval.test_case import LLMTestCase
from deepeval.metrics import SummarizationMetric
from deepeval.models.providers import OllamaModel
from ollama._types import ResponseError
import pandas as pd
import requests




# This is the original text to be summarized
# input = """
# The 'coverage score' is calculated as the percentage of assessment questions
# for which both the summary and the original document provide a 'yes' answer. This
# method ensures that the summary not only includes key information from the original
# text but also accurately represents it. A higher coverage score indicates a
# more comprehensive and faithful summary, signifying that the summary effectively
# encapsulates the crucial points and details from the original content.
# """
#
# # This is the summary, replace this with the actual output from your LLM application
# actual_output="""
# The coverage score quantifies how well a summary captures and
# accurately represents key information from the original text,
# with a higher score indicating greater comprehensiveness.
# """
#
# test_case = LLMTestCase(input=input, actual_output=actual_output)
# metric = SummarizationMetric(
#     threshold=0.5,
#     model=OllamaModel(),
#     assessment_questions=[
#         "Is the coverage score based on a percentage of 'yes' answers?",
#         "Does the score ensure the summary's accuracy with the source?",
#         "Does a higher score mean a more comprehensive summary?"
#     ]
# )
#
# # To run metric as a standalone
# metric.measure(test_case)
# print(metric.score, metric.reason)
#
# evaluate(test_cases=[test_case], metrics=[metric])

def run_evaluation(args: argparse.Namespace):
    # Build summaries with current branch.
    df = pd.read_csv(args.truthset_path)
    df['ai_summary_head'] = df.apply(get_summary, axis=1)
    df.to_csv(f"{args.output_path}/local-summary-evaluation.csv", index=False)
    df[['deep_eval_summary_score', 'deep_eval_summary_reason']] = df.apply(run_summarization_evaluation, axis=1)
    df.to_csv(f"{args.output_path}/evaluation.csv", index=False)

def get_summary(row):
    try:
        # Send the POST request
        response = requests.get('http://host.docker.internal:9000/2015-03-31/functions/function/invocations', data=json.dumps({"document_url": row['url'], 'page_limit': 7, 'model_name': 'gemini-1.5-pro-latest'}))
        return response.json()['body']
        # Todo handle bad requests.
    except requests.exceptions.RequestException as e:
        print(f"Failed to make request: {e}")
    return ''

def run_summarization_evaluation(row):
    try:
        if len(row['ai_summary_head']) == 0:
            raise RuntimeError('No AI summary found to evaluate.')
        test_case = LLMTestCase(input=row['ai_summary_baseline'], actual_output=row['ai_summary_head'])
        metric = SummarizationMetric(
            threshold=0.5,
            model=OllamaModel(),
            assessment_questions=[
                "Is the coverage score based on a percentage of 'yes' answers?",
                "Does the score ensure the summary's accuracy with the source?",
                "Does a higher score mean a more comprehensive summary?"
            ]
        )
        # To run metric as a standalone
        metric.measure(test_case)
        return pd.Series([metric.score, metric.reason])
    except (RuntimeError, ResponseError) as e:
        print(f"Ohh mama, there is something wrong with Ollama: {e}")
        return pd.Series(pd.NA, pd.NA)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Runs summary of truthset documents and does evaluation."
    )
    parser.add_argument("truthset_path", help="Path to csv truthset file.")
    parser.add_argument("output_path", help="Path to dump evaluation results.")
    args = parser.parse_args()
    run_evaluation(args)