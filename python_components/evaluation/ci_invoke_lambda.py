import json
import os

import boto3


def invoke_lambdas():
    lambda_client = boto3.client('lambda', region_name=os.environ['AWS_REGION'])
    with open(os.getenv("TRUTHSET_FILE")) as file:
        truthset = json.loads(file.read())
    for document in truthset:
        payload = {
            "evaluation_model": os.getenv("EVALUATION_MODEL"),
            "inference_model": os.getenv("INFERENCE_MODEL"),
            "evaluation_component": os.getenv("EVALUATION_COMPONENT"),
            "branch_name": os.getenv("BRANCH_NAME"),
            "commit_sha": os.getenv("COMMIT_SHA"),
            "page_limit": 7,
            "output_google_sheet": True,
            "documents": [document]
        }
        print("Outbound Payload:")
        print(json.dumps(payload, indent=2))
        response = lambda_client.invoke(
            FunctionName=os.getenv("FUNCTION_NAME"),
            InvocationType='RequestResponse',
            Payload=json.dumps(payload)
        )
        print(response['Payload'].read().decode('utf-8'))
        break



if __name__ == "__main__":
    invoke_lambdas()
