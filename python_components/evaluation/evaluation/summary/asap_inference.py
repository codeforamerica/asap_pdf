import json
import time

import requests

def get_summaries(row, inference_model_name: str):
    time.sleep(10)
    print(f'Getting summary for {row["url"]}...')
    response = requests.get(
        "http://host.docker.internal:9002/2015-03-31/functions/function/invocations",
        data=json.dumps({
            "inference_type": "summary",
            "model_name": inference_model_name,  # "gemini-1.5-pro-latest"
            "page_limit": 7,
            "documents": [{
                "title": row["file_name"],
                "id": "000",  # Does this matter?
                "purpose": row["category"],
                "url": row["url"]
            }]
        })
    ).json()
    if response['statusCode'] != 200:
        print(f'Something went wrong: {response["body"]}')
        return ""
    full_response = json.loads(response["body"])
    return full_response["000"]["summary"]