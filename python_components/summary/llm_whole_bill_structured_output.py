import argparse
import json
import logging

import llm
import pdf2image
import pypdf
from pydantic import BaseModel, Field

# Create and provide a very simple logger implementation.
logger = logging.getLogger('experiment_utility')
formatter = logging.Formatter('%(asctime)s: %(message)s')
logger.setLevel(logging.DEBUG)
ch = logging.StreamHandler()
ch.setLevel(logging.DEBUG)
ch.setFormatter(formatter)
logger.addHandler(ch)


def get_config():
    with open('config.json', 'r') as f:
        return json.load(f)


def pdf_to_attachments(pdf_path: str, output_path: str, page_limit: int) -> list:
    images = pdf2image.convert_from_path(pdf_path, fmt='jpg')
    attachments = []
    for page, image in enumerate(images):
        if 0 < page_limit - 1 < page:
            break
        page_path = f'{output_path}/page-{page}.jpg'
        image.save(page_path)
        attachments.append(llm.Attachment(path=page_path, type='image/jpeg'))
    return attachments


class DocumentEligibility(BaseModel):
    summary: str = Field(description="Two or three sentences summarizing the document.")
    is_archival: bool = Field(description="Whether the document meets 35.201 Exceptions (a) Archived web content.")
    why_archival: str = Field(description="An explanation of why the document meets or does not meet 5.201 Exceptions (a) Archived web content.")
    is_application: bool = Field(description="Whether the document meets 35.201 Exceptions (b) Preexisting conventional electronic documents.")
    why_application: str = Field(description="An explanation of why the document meets or does not meet 35.201 Exceptions (b) Preexisting conventional electronic documents.")
    is_third_party: bool = Field(description="Whether the document meets 35.201 Exceptions (c) Content posted by a third party.")
    why_third_party: str = Field(description="An explanation of why the document meets or does not meet 35.201 Exceptions (c) Content posted by a third party.")


def get_rule_text(path_to_rule) -> str:
    with open(path_to_rule, 'r') as f:
        return f.read()

rule_text = get_rule_text('./data/web-rule.txt')

PROMPT = f"""
# Government PDF ADA Compliance Exception Analyzer

You are an AI assistant specializing in ADA compliance analysis. Your task is to analyze government PDF documents and determine whether they qualify for an exception under the Department of Justice's 2024 final rule on web content and mobile app accessibility.

## The following text is a Department of Justice rule:

{rule_text}

## Document Information

  - Document title: 2023 Gann Appropriations Limit Report
  - Document purpose: Report
  - Document URL: https://www.cityofsanrafael.org/documents/san-rafael-gann-2023

## Instructions

Extract exception information about the PDF document, represented by the two attached jpegs.

"""

def run_experiment(pdf_path: str):
    config = get_config()
    attachments = pdf_to_attachments(pdf_path, './data', config['page_limit'])
    model = llm.get_model(config['active_model'])
    model.key = config['key']
    response = model.prompt(
        PROMPT,
        attachments=attachments,
        schema=DocumentEligibility,
    )
    response_json = json.loads(response.text())
    usage = response.usage()
    response_json['tokens'] = {
        'input': usage.input,
        'output': usage.output,
    }
    print(json.dumps(response_json))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Ask an LLM to respond in structured output.")
    parser.add_argument("pdf_path", help="Path to pdf")
    args = parser.parse_args()
    run_experiment(args.pdf_path)
