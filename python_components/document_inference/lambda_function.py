import json
import logging
import os
import urllib

import boto3
import llm
import pdf2image
import pypdf
import requests

import helpers




def handler(event, context):
    try:
        helpers.validate_event(event)
        local_mode = os.environ.get("ASAP_LOCAL_MODE", False)
        supported_models = helpers.get_supported_models(local_mode)
        if event["model_name"] not in helpers.supported_models.keys():
            supported_model_list = ",".join(supported_models.keys())
            raise ValueError(
                f"Unsupported model: {event["model_name"]}. Options are: {supported_model_list}"
            )

        if local_mode:
            api_key = supported_models[event["model_name"]]["key"]
            config = helpers.get_config()
            page_limit = (
                config["page_limit"]
                if event["page_limit"] == 0
                else event["page_limit"]
            )
        else:
            api_key = helpers.get_secret(
                supported_models[event["model_name"]]["key"], local_mode
            )
            page_limit = (
                "unlimited" if event["page_limit"] == 0 else event["page_limit"]
            )

        helpers.logger.info(f"Page limit set to {page_limit}.")
        model = llm.get_model(event["model_name"])
        model.key = api_key
        # Send images off to our friend.
        helpers.logger.info(f"Summarizing with {event["model_name"]}...")
        for document in event["documents"]:
            helpers.logger.info(f"Attempting to fetch document: {document["url"]}")
            # Download file locally.
            local_path = helpers.get_file(document["url"], "./data")
            document_id = document.pop("id")
            if not pypdf.PdfReader(local_path).is_encrypted:
                # Convert to images.
                helpers.logger.info("Converting to images!")
                attachments = helpers.pdf_to_attachments(
                    local_path, "./data", event["page_limit"]
                )
                num_attachments = len(attachments)
                helpers.logger.info(f"Document has {num_attachments} pages.")
                populated_prompt = PROMPT.format(**document)
                response = model.prompt(
                    populated_prompt,
                    attachments=attachments,
                    schema=DocumentEligibility,
                )
                response_json = json.loads(response.text())
                DocumentEligibility.model_validate(response_json)
                response_json["is_individualized"] = False
                response_json["is_individualized_confidence"] = 100
                response_json["why_individualized"] = (
                    'Document was not encrypted and is likely not included in the "Individualized Content" exception.'
                )
            else:
                response_json = {
                    "is_individualized": True,
                    "is_individualized_confidence": 100,
                    "why_individualized": 'Document was encrypted and should be manually evaluated for the "Individualized Content" exception.',
                }
            logging.info("Writing LLM results to Rails API...")
            # TODO figure out how to contextualize this.
            url = "http://host.docker.internal:3000/api/documents/inference"
            post_document(url, document_id, response_json)

        return {
            "statusCode": 200,
            "body": "Successfully made document recommendation.",
        }
    except Exception as e:
        return {"statusCode": 500, "body": str(e)}