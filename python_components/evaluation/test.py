import argparse
import os
import urllib
from pathlib import Path

import pandas as pd
import pdf2image
from mllmollama import MultimodalOllamaModel
from mllmsummarization import MultimodalInputSummarization
from deepeval.test_case import MLLMTestCase, MLLMImage

model = MultimodalOllamaModel()

metric = MultimodalInputSummarization(model=model,
                                      assessment_questions=[
                                          "Is the coverage score based on a percentage of 'yes' answers?",
                                          "Does the score ensure the summary's accuracy with the source?",
                                          "Does a higher score mean a more comprehensive summary?"
                                      ])


def run_evaluation(args: argparse.Namespace):
    # Build summaries with current branch.
    df = pd.read_csv(args.truthset_path)
    df['images'] = df.apply(convert_to_images, axis=1, args=(args.output_path,))
    df = df[:1]
    df.apply(summarization_evaluation, axis=1)


def summarization_evaluation(row):
    test_case = MLLMTestCase(input=row["images"], actual_output=row["ai_summary_baseline"])
    metric.measure(test_case)


def convert_to_images(row: pd.Series, output_path: str) -> list:
    file_name_stem = Path(row["file_name"]).stem
    output_folder = f"{output_path}/{file_name_stem}"
    os.makedirs(output_folder, exist_ok=True)
    # get_file(row["url"], output_folder)
    image_output = f"{output_folder}/images"
    os.makedirs(image_output, exist_ok=True)
    return pdf_to_attachments(f"{output_folder}/{row['file_name']}", image_output, 7)


def get_file(url: str, output_path: str) -> str:
    file_name = os.path.basename(url)
    local_path = f"{output_path}/{file_name}"
    urllib.request.urlretrieve(url, local_path)
    return local_path


def pdf_to_attachments(pdf_path: str, output_path: str, page_limit: int) -> list:
    images = pdf2image.convert_from_path(pdf_path, fmt="jpg")
    attachments = []
    for page, image in enumerate(images):
        if 0 < page_limit - 1 < page:
            break
        page_path = f"{output_path}/page-{page}.jpg"
        image.save(page_path)
        attachments.append(MLLMImage(page_path, local=True))
    return attachments


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Runs summary of truthset documents and does evaluation."
    )
    parser.add_argument("truthset_path", help="Path to csv truthset file.")
    parser.add_argument("output_path", help="Path to dump evaluation results.")
    args = parser.parse_args()
    run_evaluation(args)
