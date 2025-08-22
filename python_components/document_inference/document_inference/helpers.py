import json
import logging
import os
import shutil

import boto3
import fitz
import llm
import pypdf
import requests
from document_inference.prompts import RECOMMENDATION, SUMMARY
from document_inference.schemas import DocumentRecommendation, DocumentSummarySchema

# Create and provide a very simple logger implementation.
logger = logging.getLogger("experiment_utility")
formatter = logging.Formatter("%(asctime)s: %(message)s")
logger.setLevel(logging.DEBUG)
ch = logging.StreamHandler()
ch.setLevel(logging.DEBUG)
ch.setFormatter(formatter)
logger.addHandler(ch)

_document_collection = {}


def get_models(model_file: str):
    with open(model_file, "r") as f:
        return json.load(f)


def get_secret(secret_name: str, local_mode: bool, aws_env: str) -> str:
    secret_name = secret_name.format(AWS_ENV=aws_env)
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
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
        "Accept": "application/pdf,application/octet-stream,*/*",
        "Accept-Language": "en-US,en;q=0.9",
        "Accept-Encoding": "gzip, deflate",
        "DNT": "1",
        "Connection": "keep-alive",
        "Upgrade-Insecure-Requests": "1",
    }
    with requests.get(url, headers=headers, stream=True) as response:
        response.raise_for_status()
        with open(f"{output_path}/{file_name}", "wb") as file:
            shutil.copyfileobj(response.raw, file)
    return local_path


def pdf_to_attachments(
    pdf_path: str, output_path: str, page_limit: int, dpi=100
) -> list:
    doc = fitz.open(pdf_path)
    attachments = []
    file_name = os.path.splitext(os.path.basename(pdf_path))[0]
    logger.info(f"Found {doc.page_count} pages total.")
    for page_num in range(doc.page_count):
        if page_num >= page_limit:
            break
        page = doc.load_page(page_num)
        page_path = f"{output_path}/{file_name}-{page_num}.jpg"
        pix = page.get_pixmap(matrix=fitz.Matrix(dpi / 72, dpi / 72))
        pix.save(page_path)
        attachments.append(llm.Attachment(path=page_path, type="image/jpeg"))
    return attachments


def validate_event(event):
    for required_key in ("inference_type", "model_name", "documents", "page_limit"):
        if required_key not in event.keys():
            raise ValueError(
                f"Function called without required parameter, {required_key}."
            )
    valid_inference_types = ("exception", "summary")
    if event["inference_type"] not in valid_inference_types:
        valid_inference_types_list = ", ".join(valid_inference_types)
        raise RuntimeError(
            f"Function called with invalid inference type {event['inference_type']}, valid options are {valid_inference_types_list}."
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


def validate_model(all_models: dict, model_name: str):
    if model_name not in all_models.keys():
        supported_model_list = ",".join(all_models.keys())
        raise ValueError(
            f"Unsupported model: {model_name}. Options are: {supported_model_list}"
        )


def post_document(url: str, inference_type: str, json_result: dict, auth: tuple):
    data = {
        "inference_type": inference_type,
        "result": json_result,
    }
    logger.info("Here is what we are sending.")
    logger.info(data)
    # Headers (optional, but often needed for specifying content type)
    headers = {"Content-type": "application/json"}
    # Send the POST request
    response = requests.post(url, data=json.dumps(data), headers=headers, auth=auth)
    # Check the response status code
    if response.status_code > 300:
        raise RuntimeError(
            f"API Request to update document inferences failed: {response.text}"
        )


def collect_document(document_id: int, response: dict):
    _document_collection[document_id] = response


def json_dump_collection() -> str:
    return json.dumps(_document_collection)


def document_inference_summary(
    model, document: dict, local_path: str, page_limit: int
) -> dict:
    logger.info("Beginning summarization process.")
    attachments = pdf_to_attachments(local_path, "/tmp/data", page_limit)
    num_attachments = len(attachments)
    logger.info(f"Created {num_attachments} images.")
    populated_prompt = SUMMARY.format(**document)
    response = model.prompt(
        populated_prompt,
        attachments=attachments,
        schema=DocumentSummarySchema.model_json_schema(),
    )
    response_json = json.loads(response.text())
    logger.info("Inference complete. Validating response.")
    structured_output_model = DocumentSummarySchema.model_validate(response_json)
    structured_output_model.inference_model = model.model_id
    structured_output_model.usage = response.usage()
    logger.info("Validation complete.")
    return structured_output_model.model_dump()


def document_inference_recommendation(
    model, document: dict, local_path: str, page_limit: int
) -> dict:
    logger.info("Beginning recommendation process.")
    if not pypdf.PdfReader(local_path).is_encrypted:
        # Convert to images.
        logger.info("Converting to images!")
        attachments = pdf_to_attachments(local_path, "/tmp/data", page_limit)
        num_attachments = len(attachments)
        logger.info(f"Created {num_attachments} images.")
        populated_prompt = RECOMMENDATION.format(**document)
        response = model.prompt(
            populated_prompt,
            attachments=attachments,
            schema=DocumentRecommendation.model_json_schema(),
        )
        response_json = json.loads(response.text())
        logger.info("Inference complete. Validating response.")
        structured_output_model = DocumentRecommendation.model_validate(response_json)
        structured_output_model.inference_model = model.model_id
        structured_output_model.usage = response.usage()
        logger.info("Validation complete.")
    else:
        raise RuntimeError("Document was encrypted! Could not proceed.")
    return structured_output_model.model_dump()
