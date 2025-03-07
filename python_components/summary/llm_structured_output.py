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
    is_archival: bool = Field(description="Whether the document meets the 'Archived Content' exemption.")
    why_archival: str = Field(description="An explanation of how `is_archival` was determined.")
    is_fundamental_for_program_use: bool = Field(description="Whether the document meets the 'Not Fundamental for Program Use' exemption.")
    why_fundamental_for_program_use: str = Field(description="An explanation of how `is_archival` was determined.")
    is_third_party: bool = Field(description="Whether the document meets the 'Third party' exemption.")
    why_third_party: str = Field(description="An explanation of how `is_third_party` was determined.")


initial_prompt = """
You are an expert in ADA compliance and accessibility requirements for government documents.

The U.S. Department of Justice ADA rule requires that state and local government websites make their web content and documents conform with WCAG 2.1 Level AA. There are three exemptions:
1. Archived Content: Was created before April 24th, 2026; Is retained exclusively for reference, research, or recordkeeping; Is not altered or updated after the date of archiving; and Is organized and stored in a dedicated area or areas clearly identified as being archived.
2. Not Fundamental for Program Use: Not, currently used to apply for, gain access to, or participate in the public entity’s services, programs, or activities.
3. Third Party: Content posted by a third party that is not operating under contract, license or other arrangements with the city.

I am analyzing a PDF document from the City of San Rafael website. The document is titled "2023 Gann Appropriations Limit Report" and is located at "https://www.cityofsanrafael.org/documents/san-rafael-gann-2023".

The following jpg images are the pages from the document, please extract.
"""

def run_experiment(pdf_path: str):
    config = get_config()
    attachments = pdf_to_attachments(pdf_path, './data', config['page_limit'])
    model = llm.get_model(config['active_model'])
    model.key = config['key']
    response = model.prompt(
        "The following images show a local government document. Could you summarize the contents in two or three sentences?",
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
