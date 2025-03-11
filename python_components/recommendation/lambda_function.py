import json
import logging
import os
import urllib

import boto3
import llm
import pdf2image

from schema import DocumentEligibility

# Create and provide a very simple logger implementation.
logger = logging.getLogger("experiment_utility")
formatter = logging.Formatter("%(asctime)s: %(message)s")
logger.setLevel(logging.DEBUG)
ch = logging.StreamHandler()
ch.setLevel(logging.DEBUG)
ch.setFormatter(formatter)
logger.addHandler(ch)

def get_secret(secret_name: str, local_mode: bool) -> str:
    if local_mode:
        session = boto3.session.Session()
        client = session.client(
            service_name="secretsmanager",
            aws_access_key_id="no secrets",
            aws_secret_access_key="for you here",
            endpoint_url="http://localstack:4566",
            region_name="us-east-1",
        )
    else:
        session = boto3.session.Session()
        client = session.client(service_name="secretsmanager")

    response = client.get_secret_value(SecretId=secret_name)
    return response["SecretString"]


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
        attachments.append(llm.Attachment(path=page_path, type="image/jpeg"))
    return attachments


def validate_event(event):
    for required_key in ("model_name", "documents", "page_limit"):
        if required_key not in event:
            raise ValueError(
                f"Function called without required parameter, {required_key}."
            )
    documents = json.loads(event["documents"])
    if type(documents) is dict:
        documents = [documents]
    if type(documents) is not list:
        raise ValueError("Provided key documents must be a list of dictionaries or a single dictionary. It was not.")
    for i, document in documents.items():
        for key in document.keys():
            for required_document_key in ("id", "title", "purpose", "url"):
                if required_document_key not in document.keys():
                    raise ValueError(f"Document with index {i} is missing required key, {key}")

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

  - Document title: {title}
  - Document purpose: {purpose}
  - Document URL: {url}

"""

def handler(event, context):
    try:
        validate_event(event)
        for document in event["documents"]:
            document_id = document.pop("id")
            populated_prompt = PROMPT.format(**document)
            output = DocumentEligibility(
                is_archival=False,
                why_archival='Not part of an archive section',
                is_third_party=False,
                why_third_party='Created by the state.',
                is_application=False,
                why_application='Used by the government for an application.'
            )


    except Exception as e:
        return {
            "statusCode": 500,
            "body": str(e)
        }