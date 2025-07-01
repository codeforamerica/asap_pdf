import json
import logging

import boto3

# Create and provide a very simple logger implementation.
logger = logging.getLogger("experiment_utility")
formatter = logging.Formatter("%(asctime)s: %(message)s")
logger.setLevel(logging.DEBUG)
ch = logging.StreamHandler()
ch.setLevel(logging.DEBUG)
ch.setFormatter(formatter)
logger.addHandler(ch)


def get_models(model_file: str):
    with open(model_file, "r") as f:
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


def validate_model(all_models: dict, model_name: str):
    if model_name not in all_models.keys():
        supported_model_list = ",".join(all_models.keys())
        raise ValueError(
            f"Unsupported model: {model_name}. Options are: {supported_model_list}"
        )


def validate_event(event):
    for required_key in (
        "inference_model",
        "evaluation_model",
        "evaluation_component",
        "branch_name",
        "commit_sha",
        "documents",
        "page_limit",
    ):
        if required_key not in event.keys():
            raise ValueError(
                f"Function called without required parameter, {required_key}."
            )
    if event["evaluation_component"] not in ("summary", "exception"):
        raise ValueError(
            f"Unexpected value for evaluation_component, '{event['evaluation_component']}'. Expected 'summary' or 'exception'."
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
            for required_document_key in (
                "file_name",
                "category",
                "created_date",
                "url",
                "human_summary",
            ):
                if required_document_key not in document.keys():
                    raise ValueError(
                        f"Document with index {i} is missing required key, {key}"
                    )
