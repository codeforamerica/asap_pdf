from concurrent.futures import ThreadPoolExecutor, as_completed
import json
import os

from botocore.config import Config
import boto3

config = Config(
    read_timeout=900
)


def invoke_lambdas() -> list:
    lambda_client = boto3.client('lambda', region_name=os.environ['AWS_REGION'], config=config)
    with open(os.getenv("TRUTHSET_FILE")) as file:
        truthset = json.loads(file.read())
    future_to_config = {}
    with ThreadPoolExecutor(max_workers=10) as executor:
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
            future = executor.submit(
                invoke_lambda_sync,
                lambda_client,
                payload,
            )
            future_to_config[future] = config
        results = []
        for future in as_completed(future_to_config):
            try:
                result = future.result()
                results.append(result)
            except Exception as e:
                results.append({
                    'error': f"Future execution failed: {str(e)}",
                    'success': False
                })
        return results


def invoke_lambda_sync(client, payload):
    print("Outbound Payload:")
    print(json.dumps(payload, indent=2))
    response = client.invoke(
        FunctionName=os.getenv("FUNCTION_NAME"),
        InvocationType='RequestResponse',
        Payload=json.dumps(payload)
    )
    print(response['Payload'].read().decode('utf-8'))


if __name__ == "__main__":
    invoke_lambdas()
