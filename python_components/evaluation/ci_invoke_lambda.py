import json
import os

import boto3

base_payload = {
    "evaluation_model": os.getenv("EVALUATION_MODEL"),
    "inference_model": os.getenv("INFERENCE_MODEL"),
    "evaluation_component": os.getenv("EVALUATION_COMPONENT"),
    "branch_name": os.getenv("BRANCH_NAME"),
    "commit_sha": os.getenv("COMMIT_SHA"),
    "page_limit": 7,
    "output_google_sheet": True,
    "documents": []
}


def invoke_lambdas():
    truthset = json.loads("truthset.json")
    for document in truthset:
        payload = base_payload.copy()
        payload["documents"].append(document)
        print("Would execute lambda:")
        print(json.dumps(payload, indent=2))


if __name__ == "__main__":
    invoke_lambdas()
