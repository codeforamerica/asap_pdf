import argparse
import base64
import json
import logging
from typing import Optional

import google.generativeai as genai
import instructor
import pdf2image
import pypdf
from google.genai.types import Part
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
    parts = []
    for page, image in enumerate(images):
        if 0 < page_limit - 1 < page:
            break
        parts.append(
            {
                "inlineData": {
                    "data": base64.b64encode(image.tobytes()).decode("utf-8"),
                    "mimeType": "image/jpeg",
                }
            }
        )
    attachments = [
        {"role": "user", "parts": parts}
    ]
    return attachments


class DocumentEligibility(BaseModel):
    summary: str = Field(description="Two or three sentences summarizing the document.")
    is_third_party: Optional[bool] = Field(description="Whether the document meets the 'Third party' exemption.")
    why_third_party: str = Field(description="An explanation of how `is_third_party` was determined.")
    is_archival: Optional[bool] = Field(description="Whether the document meets the 'Archived Content' exemption.")
    why_archival: str = Field(description="An explanation of how `is_archival` was determined.")
    is_app: Optional[bool] = Field(description="Whether the document meets the 'Not Fundamental for Program Use' exemption.")
    why_app: str = Field(description="An explanation of how `is_archival` was determined.")

def get_encrypted_response():
    d = DocumentEligibility(
        summary= '',
        is_third_party=None,
        why_third_party='',
        is_archival=None,
        why_archival='',
        is_app=None,
        why_app='',
    )
    d_dict = d.model_dump()
    d_dict['is_encrypted'] = True
    return d_dict


initial_prompt = """
You are an expert in ADA compliance and accessibility requirements for government documents.

The U.S. Department of Justice ADA rule requires that state and local government websites make their web content and documents conform with WCAG 2.1 Level AA. There are three exemptions:
1. Archived Content: Was created before April 24th, 2026; Is retained exclusively for reference, research, or recordkeeping; Is not altered or updated after the date of archiving; and Is organized and stored in a dedicated area or areas clearly identified as being archived.
2. Not Fundamental for Program Use: Not, currently used to apply for, gain access to, or participate in the public entity’s services, programs, or activities.
3. Third Party: Content posted by a third party, unless the third party is posting due to contractual, licensing, or other arrangements with the public entity.

I am analyzing a PDF document from the City of San Rafael website. The document is titled "2023 Gann Appropriations Limit Report" and is located at "https://www.cityofsanrafael.org/documents/san-rafael-gann-2023".

The following jpg images are the pages from the document, please extract.
"""


def run_experiment(pdf_path: str):
    config = get_config()
    if not pypdf.PdfReader(pdf_path).is_encrypted:
        attachments = pdf_to_attachments(pdf_path, './data', config['page_limit'])
        messages = [{
            'role': 'user',
            'content': initial_prompt,
        }]
        messages.extend(attachments)
        client = instructor.from_gemini(
            client=genai.GenerativeModel(
                model_name="models/gemini-1.5-flash-latest",
            ),
            mode=instructor.Mode.GEMINI_JSON,
        )
        genai.configure(api_key=config['key'])

        response = client.messages.create(
            messages=messages,
            response_model=DocumentEligibility,
        )
        output = response.model_dump()
        output['is_encrypted'] = False
    else:
        output = get_encrypted_response()
    print(json.dumps(output))



if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Ask an LLM to respond in structured output.")
    parser.add_argument("pdf_path", help="Path to pdf")
    args = parser.parse_args()
    run_experiment(args.pdf_path)
