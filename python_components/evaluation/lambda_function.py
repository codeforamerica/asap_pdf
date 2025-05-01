import os
import json
import time

from deepeval.models import MultimodalGeminiModel
from pydantic import ValidationError

from evaluation import summary, utility
from evaluation.utility.helpers import logger


def handler(event, context):
    try:
        if type(event) is str:
            event = json.loads(event)
        if "body" in event:
            event = json.loads(event["body"])
        utility.helpers.logger.info(event)
        if not isinstance(event, dict):
            raise RuntimeError("Event is not a dictionary, please investigate.")
        logger.info("Validating event")
        # todo validate event.
        # helpers.validate_event(event)
        logger.info("Event is valid")
        local_mode = os.environ.get("ASAP_LOCAL_MODE", False)
        logger.info(f"Local mode set to: {local_mode}")
        logger.info("Validating LLM Judge model")
        all_models = utility.helpers.get_models("models.json")
        utility.helpers.validate_model(all_models, event["model_name"])
        logger.info("LLM Judge model is valid")
        api_key = utility.helpers.get_secret(all_models[event["model_name"]]["key"], local_mode)
        # todo Abstract: create a utility helper for this.
        model = MultimodalGeminiModel(model="gemini-2.5-pro-preview-03-25", api_key=api_key)
        if not os.path.exists("/tmp/data"):
            os.makedirs("/tmp/data")
        output = []
        for document_dict in event["documents"]:
            logger.info(f'Beginning evaluation of "{document_dict["url"]}')
            document_model = utility.document.Document.model_validate(document_dict)
            logger.info(f'Converting document to images "{document_dict["url"]}')
            utility.document.add_images_to_document(document_model, "/tmp/data")
            logger.info(f'Created {len(document_model.images)}')
            logger.info(f"Beginning summarization.")
            # todo parameterize this.
            time.sleep(10)
            summary.add_summary_to_document(document_model, "gemini-1.5-pro-latest", local_mode)
            logger.info(f"Summarization complete.")
            result = summary.evaluation(document_model, model)
            output.append(dict(result))
            logger.info(f"Evaluation complete.")
        if "asap_endpoint" in event.keys():
            logger.info("Writing eval results to Rails API")
            # todo write API endpoint and put a call here.
            return {
                "statusCode": 200,
                "body": "Successfully made document recommendation.",
            }
        elif "output_s3_bucket" in event.keys():
            # todo fail here if local_mode is true.
            logger.info(f'Writing eval results to S3 bucket, {event["output_s3_bucket"]}.')
            report_name = f'{event["branch_name"]}-{event["commit_sha"][:5]}.csv'
            utility.document.write_output_to_s3(event["output_s3_bucket"], report_name, output)
            return {
                "statusCode": 200,
                "body": f'Successfully dumped report to S3 bucket, {event["output_s3_bucket"]}.',
            }
        else:
            logger.info("Dumping results into Lambda return")
            return {"statusCode": 200, "body": json.dumps(output)}
    except ValidationError as e:
        message = f'Invalid document supplied to event: {str(e)}'
        return {"statusCode": 500, "body": message}
    except Exception as e:
        return {"statusCode": 500, "body": str(e)}
