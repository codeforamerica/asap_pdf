import argparse
import json
import os

import llm

from document_inference import helpers


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
        helpers.logger.info("Validating model")
        all_models = helpers.get_models("models.json")
        helpers.validate_model(all_models, event["model_name"])
        helpers.logger.info("Model is valid")
        api_key = helpers.get_secret(all_models[event["model_name"]]["key"], local_mode)
        page_limit_label = (
            "unlimited" if event["page_limit"] == 0 else event["page_limit"]
        )
        helpers.logger.info(f"Page limit set to {page_limit_label}.")
        model = llm.get_model(event["model_name"])
        model.key = api_key
        if not os.path.exists("/tmp/data"):
            os.makedirs("/tmp/data")
        # Send images off to our friend.
        helpers.logger.info(f"Summarizing with {event["model_name"]}...")
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
                    event["asap_endpoint"], event["inference_type"], response
                )
            else:
                helpers.logger.info("Dumping results into Lambda return")
                helpers.collect_document(document["id"], response)
        if "asap_endpoint" in event.keys():
            return {
                "statusCode": 200,
                "body": "Successfully made document recommendation.",
            }
        else:
            return {"statusCode": 200, "body": helpers.json_dump_collection()}
    except Exception as e:
        return {"statusCode": 500, "body": str(e)}
