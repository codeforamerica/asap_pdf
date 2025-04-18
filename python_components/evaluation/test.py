import argparse
import os
import urllib
from pathlib import Path
import json

import time
import requests
import pandas as pd
import pdf2image
from mllmsummarization import MultimodalInputSummarization
from mllmollama import MultimodalOllamaModel
from deepeval.models import MultimodalGeminiModel
from deepeval.test_case import MLLMTestCase, MLLMImage
from deepeval.utils import prettify_list

model = MultimodalGeminiModel(model="gemini-2.5-pro-preview-03-25")

examples = [
    ["MINUTES%20December%202024.pdf", "https://agr.georgia.gov/sites/default/files/documents/pest-control/MINUTES%20December%202024.pdf", "Agenda"],
    ["VA S.A.V.E. Training One-Pager", "https://www.mentalhealth.va.gov/suicide_prevention/docs/VA_SAVE_Training.pdf", "Brochure"],
    ["atlanta-market-map.pdf", "https://agr.georgia.gov/sites/default/files/documents/agritourism/atlanta-market-map.pdf", "Diagram"],
    ["Microsoft Word - One-page reasonable accommodation form.docx", "https://www.austintexas.gov/sites/default/files/files/HR/One-page_reasonable_accommodation_form.pdf", "Form"],
    ["2013.07.16_PlanningCommission.pdf", "http://www.slcdocs.com/attorney/COI/2013.07.16_PlanningCommission.pdf", "Letter"],
    ["Font Size:  12", "https://services.austintexas.gov/edims/document.cfm?id=446835", "Notice"],
    ["08.14.15.14.pdf", "https://nathandeal.georgia.gov/sites/nathandeal.georgia.gov/files/related_files/document/08.14.15.14.pdf", "Policy"],
    ["5.b-Vacancies-on-Boards-and-Commissions.pdf", "https://storage.googleapis.com/proudcity/sanrafaelca/uploads/2021/07/5.b-Vacancies-on-Boards-and-Commissions.pdf", "Report"],
    ["Microsoft PowerPoint - Council Workession Update on Bond Development 4-3-17 FINAL.pptx", "https://services.austintexas.gov/edims/document.cfm?id=274486", "Slides"],
    ["July-2016-WCE-Salary-Schedule.pdf", "https://storage.googleapis.com/proudcity/sanrafaelca/uploads/2016/09/July-2016-WCE-Salary-Schedule.pdf", "Spreadsheet"]
]


def run_evaluation(args: argparse.Namespace):
    # Build summaries with current branch.
    df = pd.read_csv(f"{args.output_path}/summarized.csv")
    #df = pd.DataFrame(examples)
    #df.transpose()
    #df.columns = ['file_name', 'url', 'category']
    #df = df[:1]
    #df['summary'] = df.apply(get_summaries, axis=1)
    #df.to_csv(f"{args.output_path}/summarized.csv", index=False)
    df['images'] = df.apply(convert_to_images, axis=1, args=(args.output_path,))
        #df = df[df['language'] == 'en']
    df[['score', 'reason', 'detail']] = df.apply(summarization_evaluation, axis=1, result_type='expand')
    df.to_csv(f"{args.output_path}/output.csv", index=False)


def get_summaries(row):
    time.sleep(10)
    print(f'Getting summary for {row["url"]}...')
    response = requests.get(
        "http://host.docker.internal:9002/2015-03-31/functions/function/invocations",
        data=json.dumps({
            "inference_type": "summary",
            "model_name": "gemini-1.5-pro-latest",  # "claude-3.5-haiku", # "gemini-2.0-pro-exp-02-05",
            "page_limit": 7,
            "documents": [{
                "title": row["file_name"],
                "id": "000",  # Does this matter?
                "purpose": row["category"],
                "url": row["url"]
            }]
        })
    ).json()
    if response['statusCode'] != 200:
        print(f'Something went wrong: {response["body"]}')
        return ""
    full_response = json.loads(response["body"])
    return full_response["000"]["summary"]


def summarization_evaluation(row):
    if len(row['summary']) == 0:
        return pd.Series()
    metric = MultimodalInputSummarization(model=model, verbose_mode=True)
    test_case = MLLMTestCase(input=row["images"], actual_output=row["summary"])
    metric.measure(test_case)
    details = {
        'truths': prettify_list(metric.truths),
        'claims': prettify_list(metric.claims),
        'assessment_questions': prettify_list(metric.assessment_questions),
        'coverage_verdicts': prettify_list(metric.coverage_verdicts),
        'alignment_verdicts': prettify_list(metric.alignment_verdicts),
    }
    return pd.Series([metric.score, metric.reason, json.dumps(details)])
    # print(metric.reason)
    # print(z)


def convert_to_images(row: pd.Series, output_path: str) -> list:
    path_obj = Path(row["url"])
    file_name_stem = path_obj.stem
    if '.cfm' in path_obj.suffix:
        file_name_stem += path_obj.suffix
    print(file_name_stem)
    output_folder = f"{output_path}/{file_name_stem}"
    os.makedirs(output_folder, exist_ok=True)
    get_file(row["url"], output_folder)
    image_output = f"{output_folder}/images"
    os.makedirs(image_output, exist_ok=True)
    return pdf_to_attachments(f"{output_folder}/{path_obj.name}", image_output, 7)


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
    #parser.add_argument("truthset_path", help="Path to csv truthset file.")
    parser.add_argument("output_path", help="Path to dump evaluation results.")
    args = parser.parse_args()
    run_evaluation(args)
