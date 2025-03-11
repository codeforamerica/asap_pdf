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
    # summary: str = Field(description="Two or three sentences summarizing the document.")
    is_archival: bool = Field(description="Whether the document meets exception 1: Archived Web Content Exception")
    why_archival: str = Field(description="An explanation of why the document meets or does not meet exception 1: Archived Web Content Exception")
    is_application: bool = Field(description="Whether the document meets exception 2: Preexisting Conventional Electronic Documents Exception")
    why_application: str = Field(description="An explanation of why the document meets or does not meet exception 2: Preexisting Conventional Electronic Documents Exception")
    is_third_party: bool = Field(description="Whether the document meets exception 3: Content Posted by Third Parties Exception")
    why_third_party: str = Field(description="An explanation of why the document meets or does not meet exception 3: Content Posted by Third Parties Exception")


PROMPT = """
# Government PDF ADA Compliance Exception Analyzer

You are an AI assistant specializing in ADA compliance analysis. Your task is to analyze government PDF documents and determine whether they qualify for an exception under the Department of Justice's 2024 final rule on web content and mobile app accessibility.

## Context

The Department of Justice published a final rule updating regulations for Title II of the Americans with Disabilities Act (ADA). This rule requires state and local governments to ensure their web content and mobile apps are accessible to people with disabilities according to WCAG 2.1, Level AA standards. However, certain PDF documents may qualify for exceptions.

## Your Task

The attached jpeg documents represent a PDF. Analyze the PDF document information and determine whether it qualifies for an exception from WCAG 2.1, Level AA compliance requirements under one of the following exception categories:

1. **Archived Web Content Exception** - Applies when ALL of these conditions are met:
   - Created before the compliance date April 24, 2026
   - Kept only for reference, research, or recordkeeping
   - Stored in a special area for archived content
   - Has not been changed since it was archived

2. **Preexisting Conventional Electronic Documents Exception** - Applies when ALL conditions are met:
   - Document is a PDF file
   - Document was available on the government's website or mobile app before the compliance date
   - HOWEVER: This exception does NOT apply if the document is currently being used by individuals to apply for, access, or participate in government services

3. **Content Posted by Third Parties Exception** - Applies when:
   - Content is posted by third parties (members of the public or others not controlled by or acting for government entities)
   - The third party is not posting due to contractual, licensing, or other arrangements with the government entity
   - HOWEVER: This exception does NOT apply to content posted by the government itself, content posted by government contractors/vendors, or to tools/platforms that allow third parties to post content

## Document Information

  - Document title: 2023 Gann Appropriations Limit Report
  - Document purpose: Report
  - Document URL: https://www.cityofsanrafael.org/documents/san-rafael-gann-2023

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
