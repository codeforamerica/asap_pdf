import json
import os

import llm
from document_inference import helpers

API_USER_NAME_SECRET = "asap-pdf/{AWS_ENV}/RAILS_API_USER"
API_PASSWORD_SECRET = "asap-pdf/{AWS_ENV}/RAILS_API_PASSWORD"


def handler(event, context):
    try:
        if type(event) is str:
            event = json.loads(event)
        if "body" in event:
            event = json.loads(event["body"])
        helpers.logger.info(event)
        if not isinstance(event, dict):
            raise RuntimeError("Event is not a dictionary, please investigate.")
        helpers.logger.info("Validating event")
        helpers.validate_event(event)
        helpers.logger.info("Event is valid")
        local_mode = os.environ.get("ASAP_LOCAL_MODE", False)
        aws_env = os.environ.get("AWS_ENV", "staging")
        helpers.logger.info(f"AWS environment: {aws_env}")
        helpers.logger.info("Validating model")
        all_models = helpers.get_models("models.json")
        helpers.validate_model(all_models, event["model_name"])
        helpers.logger.info("Model is valid")
        api_key = helpers.get_secret(
            all_models[event["model_name"]]["key"], local_mode, aws_env
        )
        asap_creds_user = helpers.get_secret(API_USER_NAME_SECRET, local_mode, aws_env)
        asap_creds_password = helpers.get_secret(
            API_PASSWORD_SECRET, local_mode, aws_env
        )
        page_limit_label = (
            "unlimited" if event["page_limit"] == 0 else event["page_limit"]
        )
        helpers.logger.info(f"Page limit set to {page_limit_label}.")
        model = llm.get_model(event["model_name"])
        model.key = api_key
        if not os.path.exists("/tmp/data"):
            os.makedirs("/tmp/data")
        # Send images off to our friend.
        helpers.logger.info(
            f"Summarizing or generating exception likelihood with {event["model_name"]}..."
        )
        for document in event["documents"]:
            helpers.logger.info(f"Attempting to fetch document: {document["url"]}")
            # Download file locally.
            local_path = helpers.get_file(document["url"], "/tmp/data")
            helpers.logger.info(f"Performing inference with {event['model_name']}...")
            if event["inference_type"] == "exception":
                response = helpers.document_inference_recommendation(
                    model, document, local_path, event["page_limit"]
                )
            elif event["inference_type"] == "summary":
                response = helpers.document_inference_summary(
                    model, document, local_path, event["page_limit"]
                )
            else:
                raise RuntimeError(f"Unknown inference type: {event['inference_type']}")
            if "asap_endpoint" in event.keys():
                helpers.logger.info("Writing LLM results to Rails API")
                helpers.post_document(
                    event["asap_endpoint"],
                    event["inference_type"],
                    response,
                    (asap_creds_user, asap_creds_password),
                )
            else:
                helpers.logger.info("Dumping results into Lambda return")
                helpers.collect_document(document["id"], response)
        # Making a change to the handler to force layer rebuild.
        helpers.logger.info("Rebuild this layer")
        if "asap_endpoint" in event.keys():
            return {
                "statusCode": 200,
                "body": "Successfully made document recommendation.",
            }
        else:
            return {"statusCode": 200, "body": helpers.json_dump_collection()}
    except Exception as e:
        helpers.logger.error(f"Error during execution: {e}")
        return {"statusCode": 500, "body": str(e)}
