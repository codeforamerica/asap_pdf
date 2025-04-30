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
    headers = {
        "Content-Type": "application/json",  # Changed from application/x-amz-json-1.1
        "Accept": "application/json"
    }
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
    response = requests.post(url, data=payload, auth=signature, headers=headers)
    logger.info(f"Status code: {response.status_code}")
    logger.info(f"Response headers: {response.headers}")
    try:
        response_text = response.text
        logger.info(f'Raw response: {response_text[:200]}...')
        response_json = response.json()
    except json.JSONDecodeError as e:
        logger.error(f'Failed to parse JSON response: {e}')
        logger.error(f'Response content: {response.text}')
        logger.error(f'Status code: {response.status_code}')
        raise RuntimeError(f'Failed to parse response from Lambda: {str(e)}')

    if response_json.get('statusCode') != 200:
        error_body = response_json.get('body', 'No error details available')
        raise RuntimeError(f'Failed to get summary: {error_body}')

    logger.info(f'Made request.')
    response = response.json()
    if response['statusCode'] != 200:
        raise RuntimeError(f'Failed to get summary: {response["body"]}')

    try:
        full_response = json.loads(response_json["body"])
        document.ai_summary = full_response["000"]["summary"]
    except json.JSONDecodeError as e:
        logger.error(f'Failed to parse response body: {e}')
        logger.error(f'Response body: {response_json["body"]}')
        raise RuntimeError(f'Failed to parse summary response body: {str(e)}')
    except KeyError as e:
        logger.error(f'Missing expected key in response: {e}')
        logger.error(f'Full response structure: {full_response}')
        raise RuntimeError(f'Missing expected data in summary response: {str(e)}')

    document.ai_summary = full_response["000"]["summary"]
