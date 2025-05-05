import json
import os
import time

from deepeval.models import MultimodalGeminiModel
from evaluation import summary, utility
from evaluation.utility.helpers import logger
from pydantic import ValidationError


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
        utility.helpers.validate_event(event)
        logger.info("Event is valid")
        local_mode = os.environ.get("ASAP_LOCAL_MODE", False)
        logger.info(f"Local mode set to: {local_mode}")
        logger.info("Validating LLM Judge model")
        all_models = utility.helpers.get_models("models.json")
        utility.helpers.validate_model(all_models, event["evaluation_model"])
        logger.info("LLM Judge model is valid")
        api_key = utility.helpers.get_secret(
            all_models[event["evaluation_model"]]["key"], local_mode
        )
        # todo Abstract: create a utility helper for this.
        eval_model = MultimodalGeminiModel(
            model=event["evaluation_model"], api_key=api_key
        )
        if not os.path.exists("/tmp/data"):
            os.makedirs("/tmp/data")
        output = []
        for document_dict in event["documents"]:
            logger.info(f'Beginning evaluation of "{document_dict["url"]}')
            document_model = utility.document.Document.model_validate(document_dict)
            logger.info(f'Converting document to images "{document_dict["url"]}')
            utility.document.add_images_to_document(
                document_model, "/tmp/data", event["page_limit"]
            )
            logger.info(f"Created {len(document_model.images)}")
            logger.info("Beginning summarization.")
            time.sleep(10)
            # todo abstract this for other domains besides "summary"
            summary.add_summary_to_document(
                document_model,
                event["inference_model"],
                local_mode,
                event["page_limit"],
            )
            logger.info("Summarization complete. Performing related evaluations.")
            result = summary.evaluation(
                event["branch_name"], event["commit_sha"], document_model, eval_model
            )
            result.evaluation_model = event["evaluation_model"]
            result.inference_model = event["inference_model"]
            output.append(dict(result))
            logger.info("Calculating Rouge score.")
            result = summary.calculate_rouge_score(
                event["branch_name"], event["commit_sha"], document_model
            )
            result.inference_model = event["inference_model"]
            output.append(dict(result))
            logger.info("Evaluation complete.")
        if "asap_endpoint" in event.keys():
            logger.info("Writing eval results to Rails API")
            # todo write API endpoint and put a call here.
            return {
                "statusCode": 200,
                "body": "Successfully made document recommendation.",
            }
        elif "output_s3_bucket" in event.keys():
            if local_mode:
                raise RuntimeError(
                    "Local development is not supported S3 dumping mode. Do not include the `output_s3_bucket` event key."
                )
            logger.info(
                f'Writing eval results to S3 bucket, {event["output_s3_bucket"]}.'
            )
            report_name = f'{event["branch_name"]}-{event["commit_sha"][:5]}.csv'
            utility.document.write_output_to_s3(
                event["output_s3_bucket"], report_name, output
            )
            return {
                "statusCode": 200,
                "body": f'Successfully dumped report to S3 bucket, {event["output_s3_bucket"]}.',
            }
        else:
            logger.info("Dumping results into Lambda return")
            return {"statusCode": 200, "body": json.dumps(output)}
    except ValidationError as e:
        message = f"Invalid document supplied to event: {str(e)}"
        return {"statusCode": 500, "body": message}
    except Exception as e:
        return {"statusCode": 500, "body": str(e)}
