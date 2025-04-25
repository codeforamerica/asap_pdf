import json
import time

import requests

from evaluation.utility.document import Document


def add_summary_to_document(document: Document, inference_model_name: str) -> None:
    time.sleep(10)
    print(f'Getting summary for {document.url}...')
    response = requests.get(
        "http://host.docker.internal:9002/2015-03-31/functions/function/invocations",
        data=json.dumps({
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
    ).json()
    if response['statusCode'] != 200:
        raise RuntimeError(f'Failed to get summary: {response["body"]}')
    full_response = json.loads(response["body"])
    document.ai_summary = full_response["000"]["summary"]