import json

import boto3
import requests
from evaluation.utility.document import Document
from evaluation.utility.helpers import logger
from requests_aws4auth import AWS4Auth


def get_signature(session):
    credentials = session.get_credentials()
    sigv4auth = AWS4Auth(
        credentials.access_key,
        credentials.secret_key,
        session.region_name,
        "lambda",
        session_token=credentials.token,
    )
    return sigv4auth


def get_inference_for_document(
    document: Document,
    inference_model_name: str,
    inference_type: str,
    local_mode: bool,
    page_number: int,
) -> None:
    logger.info(f"Performing inference type {inference_type} for {document.url}...")
    if local_mode:
        url = (
            "http://host.docker.internal:9002/2015-03-31/functions/function/invocations"
        )
        session = boto3.session.Session(
            aws_access_key_id="no secrets",
            aws_secret_access_key="for you here",
            region_name="us-east-1",
        )
    else:
        session = boto3.Session()
        client = session.client("lambda")
        response = client.get_function_url_config(
            FunctionName="asap-pdf-document-inference-evaluation-production",
        )
        if "FunctionArn" not in response.keys():
            raise RuntimeError(
                f"Could not determine Lambda function url: {json.dumps(response)}"
            )
        url = response["FunctionUrl"]
    signature = get_signature(session)
    logger.info(f"Created signature. Url is: {url}")
    headers = {
        "Content-Type": "application/json",  # Changed from application/x-amz-json-1.1
        "Accept": "application/json",
    }
    payload = json.dumps(
        {
            "inference_type": inference_type,
            "model_name": inference_model_name,  # "gemini-1.5-pro-latest"
            "page_limit": page_number,
            "documents": [
                {
                    "title": document.file_name,
                    "id": "000",  # Does this matter?
                    "created_date": document.created_date,
                    "purpose": document.category,
                    "url": document.url,
                }
            ],
        }
    )
    logger.info(payload)
    response = requests.post(url, data=payload, auth=signature, headers=headers)
    logger.info(f"Status code: {response.status_code}")
    logger.info(f"Response headers: {response.headers}")
    try:
        response_text = response.text
        logger.info(f"Raw response: {response_text[:200]}...")
        response_json = response.json()
    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse JSON response: {e}")
        logger.error(f"Response content: {response.text}")
        logger.error(f"Status code: {response.status_code}")
        raise RuntimeError(f"Failed to parse response from Lambda: {str(e)}")
    keys = ",".join(list(response_json.keys()))
    logger.info(f"Response included: {keys}")
    if (
        "statusCode" in response_json.keys() and int(response_json["statusCode"]) != 200
    ) or int(response.status_code) != 200:
        raise RuntimeError(f"Document inference failed: {response_json["body"]}")
    if "body" in response_json.keys():
        if type(response_json["body"]) is str:
            full_response = json.loads(response_json["body"])
        else:
            full_response = response_json["body"]
    else:
        full_response = response_json
    return full_response["000"]
