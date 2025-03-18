import json
import logging
import os
import urllib.request

import boto3
import llm
import pdf2image


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


def get_summary(model_name: str, api_key: str, attachments: list) -> str:
    model = llm.get_model(model_name)
    model.key = api_key
    response = model.prompt(
        "The following images show a local government document. Could you summarize the contents in two or three sentences?",
        # noqa: E501
        attachments=attachments,
    )
    return response.text()


def handler(event, context):
    try:
        for required_key in ("model_name", "document_url", "page_limit"):
            if required_key not in event:
                raise ValueError(
                    f"Function called without required parameter, {required_key}."
                )

        local_mode = os.environ.get("ASAP_LOCAL_MODE", False)
        supported_models = get_supported_models(local_mode)

        if event["model_name"] not in supported_models.keys():
            supported_model_list = ",".join(supported_models.keys())
            raise ValueError(
                f"Unsupported model: {event['model_name']}. Options are: {supported_model_list}"
            )

        if local_mode:
            api_key = supported_models[event["model_name"]]["key"]
            config = get_config()
            page_limit = (
                config["page_limit"]
                if event["page_limit"] == 0
                else event["page_limit"]
            )
        else:
            api_key = get_secret(
                supported_models[event["model_name"]]["key"], local_mode
            )
            page_limit = (
                "unlimited" if event["page_limit"] == 0 else event["page_limit"]
            )

        logger.info(f"Page limit set to {page_limit}.")
        logger.info(f"Attempting to fetch document: {event['document_url']}")

        # Download file locally.
        local_path = get_file(event["document_url"], "./data")

        # Convert to images.
        logger.info("Converting to images!")
        attachments = pdf_to_attachments(local_path, "./data", event["page_limit"])
        num_attachments = len(attachments)
        logger.info(f"Document has {num_attachments} pages.")

        # Send images off to our friend.
        logger.info(f"Summarizing with {event['model_name']}...")
        summary = get_summary(event["model_name"], api_key, attachments)
    except Exception as e:
        return {
            "statusCode": 500,
            "body": str(e),
        }
    return {
        "statusCode": 200,
        "body": summary,
    }
