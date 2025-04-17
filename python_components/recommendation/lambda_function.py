import json
import logging
import os
import urllib

import boto3
import llm
import pdf2image
import pypdf
import requests
from pydantic import BaseModel, Field

# Create and provide a very simple logger implementation.
logger = logging.getLogger("experiment_utility")
formatter = logging.Formatter("%(asctime)s: %(message)s")
logger.setLevel(logging.DEBUG)
ch = logging.StreamHandler()
ch.setLevel(logging.DEBUG)
ch.setFormatter(formatter)
logger.addHandler(ch)


def get_models():
    with open("models.json", "r") as f:
        return json.load(f)


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
    file_name = os.path.splitext(os.path.basename(pdf_path))[0]
    for page, image in enumerate(images):
        if 0 < page_limit - 1 < page:
            break
        page_path = f"{output_path}/{file_name}-{page}.jpg"
        image.save(page_path)
        attachments.append(llm.Attachment(path=page_path, type="image/jpeg"))
    return attachments


def validate_event(event):
    for required_key in ("model_name", "documents", "page_limit", "asap_endpoint"):
        if required_key not in event:
            raise ValueError(
                f"Function called without required parameter, {required_key}."
            )
    documents = event["documents"]
    if type(documents) is dict:
        documents = [documents]
    if type(documents) is not list:
        raise ValueError(
            "Provided key documents must be a list of dictionaries or a single dictionary. It was not."
        )
    for i, document in enumerate(documents):
        for key in document.keys():
            for required_document_key in ("id", "title", "purpose", "url"):
                if required_document_key not in document.keys():
                    raise ValueError(
                        f"Document with index {i} is missing required key, {key}"
                    )


class DocumentEligibility(BaseModel):
    is_archival: bool = Field(
        description="Whether the document meets exception 1: Archived Web Content Exception"
    )
    why_archival: str = Field(
        description="An explanation of why the document meets or does not meet exception 1: Archived Web Content Exception"
    )
    is_archival_confidence: float = Field(
        description="Percentage representing how confident you are about whether the document meets exception 1: Archived Web Content Exception"
    )
    is_application: bool = Field(
        description="Whether the document meets exception 2: Preexisting Conventional Electronic Documents Exception"
    )
    why_application: str = Field(
        description="An explanation of why the document meets or does not meet exception 2: Preexisting Conventional Electronic Documents Exception"
    )
    is_application_confidence: float = Field(
        description="Percentage representing how confident you are about whether the document meets exception 2: Preexisting Conventional Electronic Documents Exception"
    )
    is_third_party: bool = Field(
        description="Whether the document meets exception 3: Content Posted by Third Parties Exception"
    )
    why_third_party: str = Field(
        description="An explanation of why the document meets or does not meet exception 3: Content Posted by Third Parties Exception"
    )
    is_third_party_confidence: float = Field(
        description="Percentage representing how confident you are about whether the document meets exception 3: Content Posted by Third Parties Exception"
    )


def post_document(url: str, document_id: int, json_result: dict):
    data = {
        "documents": [],
    }
    # TODO make rails accept and deal with DocumentEligibility.
    bool_fields = (
        "is_individualized",
        "is_archival",
        "is_application",
        "is_third_party",
    )
    for field in bool_fields:
        if field in json_result.keys():
            record = {
                "document_id": document_id,
                "type": f"exception:{field}",
                "value": json_result[field],
                "reason": json_result[field.replace("is", "why")],
                "confidence": json_result[f"{field}_confidence"],
            }
            data["documents"].append(record)
    # Headers (optional, but often needed for specifying content type)
    headers = {"Content-type": "application/json"}
    # Send the POST request
    response = requests.post(url, data=json.dumps(data), headers=headers)
    # Check the response status code
    if response.status_code > 300:
        raise RuntimeError(
            f"API Request to update document inferences failed: {response.text}"
        )


PROMPT = """
# Government PDF ADA Compliance Exception Analyzer

You are an AI assistant specializing in ADA compliance analysis. Your task is to analyze government PDF documents and determine whether they qualify for an exception under the Department of Justice"s 2024 final rule on web content and mobile app accessibility.

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
   - Document was available on the government"s website or mobile app before the compliance date
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
        logger.info("Validating payload...")
        validate_event(event)
        local_mode = os.environ.get("ASAP_LOCAL_MODE", False)
        supported_models = get_models()
        if event["model_name"] not in supported_models.keys():
            supported_model_list = ",".join(supported_models.keys())
            raise ValueError(
                f"Unsupported model: {event["model_name"]}. Options are: {supported_model_list}"
            )
        api_key = get_secret(supported_models[event["model_name"]]["key"], local_mode)
        page_limit = "unlimited" if event["page_limit"] == 0 else event["page_limit"]
        logger.info(f"Page limit set to {page_limit}.")
        model = llm.get_model(event["model_name"])
        model.key = api_key
        # Send images off to our friend.
        logger.info(f"Summarizing with {event["model_name"]}...")
        for document in event["documents"]:
            logger.info(f"Attempting to fetch document: {document["url"]}")
            # Download file locally.
            local_path = get_file(document["url"], "./data")
            document_id = document.pop("id")
            if not pypdf.PdfReader(local_path).is_encrypted:
                # Convert to images.
                logger.info("Converting to images!")
                attachments = pdf_to_attachments(
                    local_path, "./data", event["page_limit"]
                )
                num_attachments = len(attachments)
                logger.info(f"Document has {num_attachments} pages.")
                populated_prompt = PROMPT.format(**document)
                response = model.prompt(
                    populated_prompt,
                    attachments=attachments,
                    schema=DocumentEligibility,
                )
                response_json = json.loads(response.text())
                DocumentEligibility.model_validate(response_json)
                response_json["is_individualized"] = False
                response_json["is_individualized_confidence"] = 100
                response_json["why_individualized"] = (
                    'Document was not encrypted and is likely not included in the "Individualized Content" exception.'
                )
            else:
                response_json = {
                    "is_individualized": True,
                    "is_individualized_confidence": 100,
                    "why_individualized": 'Document was encrypted and should be manually evaluated for the "Individualized Content" exception.',
                }
            logging.info("Writing LLM results to Rails API...")
            post_document(event["asap_endpoint"], document_id, response_json)

        return {
            "statusCode": 200,
            "body": "Successfully made document recommendation.",
        }
    except Exception as e:
        return {"statusCode": 500, "body": str(e)}
