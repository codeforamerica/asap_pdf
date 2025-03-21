import json
import logging
import os
import urllib

import boto3
import llm
import pdf2image

# Create and provide a very simple logger implementation.
logger = logging.getLogger("experiment_utility")
formatter = logging.Formatter("%(asctime)s: %(message)s")
logger.setLevel(logging.DEBUG)
ch = logging.StreamHandler()
ch.setLevel(logging.DEBUG)
ch.setFormatter(formatter)
logger.addHandler(ch)


def get_config():
    with open("config.json", "r") as f:
        return json.load(f)


def get_models():
    with open("models.json", "r") as f:
        return json.load(f)


def get_supported_models(local_mode):
    if local_mode:
        config = get_config()
        return {config["active_model"]: {"key": config["key"]}}
    else:
        return get_models()


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
    for required_key in ("inference_type", "model_name", "documents", "page_limit"):
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
