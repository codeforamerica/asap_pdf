import json

import boto3
from requests_aws4auth import AWS4Auth
import requests

from evaluation.utility.document import Document
from evaluation.utility.helpers import logger


def get_signature(session):
    credentials = session.get_credentials()
    sigv4auth = AWS4Auth(credentials.access_key, credentials.secret_key,
                         session.region_name, "lambda", session_token=credentials.token)
    return sigv4auth


def add_summary_to_document(document: Document, inference_model_name: str, local_mode: bool) -> None:
    logger.info(f'Getting summary for {document.url}...')
    if local_mode:
        url = "http://host.docker.internal:9002/2015-03-31/functions/function/invocations"
        session = boto3.session.Session(
            aws_access_key_id="no secrets",
            aws_secret_access_key="for you here",
            region_name="us-east-1",
        )
    else:
        session = boto3.Session()
        client = session.client("lambda")
        response = client.get_function_url_config(
            FunctionName='asap-pdf-document-inference-evaluation-production',
        )
        if "FunctionArn" not in response.keys():
            raise RuntimeError(f"Could not determine Lambda function url: {json.dumps(response)}")
        url = response['FunctionUrl']
    signature = get_signature(session)
    logger.info(f'Created signature. Summary url is: {url}')
    payload = json.dumps({
        "inference_type": "summary",
        "model_name": inference_model_name,  # "gemini-1.5-pro-latest"
        "page_limit": 7,
        "documents": [{
            "title": document.file_name,
            "id": "000",  # Does this matter?
            "purpose": document.category,
            "url": document.url
        }]
    })
    logger.info(payload)
    response = requests.get(url, data=payload, auth=signature, headers={"Content-Type": "application/x-amz-json-1.1"})
    logger.info(f'Made request.')
    response = response.json()
    if response['statusCode'] != 200:
        raise RuntimeError(f'Failed to get summary: {response["body"]}')
    logger.info(f'Here it is')
    logger.info(response["body"])
    full_response = json.loads(response["body"])
    document.ai_summary = full_response["000"]["summary"]
