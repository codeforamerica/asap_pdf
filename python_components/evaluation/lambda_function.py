import asyncio
import json
import os
import traceback

from deepeval.models import MultimodalGeminiModel
from evaluation import exception, summary, utility
from pydantic import ValidationError


def handler(event, context):
    local_mode = os.environ.get("ASAP_LOCAL_MODE", False)
    try:
        if type(event) is str:
            event = json.loads(event)
        if "body" in event:
            event = json.loads(event["body"])
        utility.helpers.logger.info(event)
        if not isinstance(event, dict):
            raise RuntimeError("Event is not a dictionary, please investigate.")
        utility.helpers.logger.info("Validating event")
        utility.helpers.validate_event(event)
        utility.helpers.logger.info("Event is valid")
        utility.helpers.logger.info(f"Local mode set to: {local_mode}")
        aws_env = os.environ.get("AWS_ENV", "staging")
        utility.helpers.logger.info(f"AWS environment: {aws_env}")
        utility.helpers.logger.info("Validating LLM Judge model")
        all_models = utility.helpers.get_models("models.json")
        utility.helpers.validate_model(all_models, event["evaluation_model"])
        utility.helpers.logger.info("LLM Judge model is valid")
        api_key = utility.helpers.get_secret(
            all_models[event["evaluation_model"]]["key"], local_mode, aws_env
        )
        # todo Abstract: create a utility helper for this.
        eval_model = MultimodalGeminiModel(
            model_name=event["evaluation_model"], api_key=api_key
        )
        if not os.path.exists("/tmp/data"):
            os.makedirs("/tmp/data")
        # Delta from Github actions is 1 indexed.
        # If delta is provided subtract one, so we can maintain zero indexing.
        delta = int(event["delta"]) - 1 if "delta" in event else 0
        delta = 0 if delta < 0 else delta
        summary_eval_wrapper = summary.EvaluationWrapper(
            eval_model,
            event["inference_model"],
            event["branch_name"],
            event["commit_sha"],
            delta,
            local_mode=local_mode,
        )
        exception_eval_wrapper = exception.EvaluationWrapper(
            eval_model,
            event["inference_model"],
            event["branch_name"],
            event["commit_sha"],
            delta,
            local_mode=local_mode,
        )
        output = []
        for document_dict in event["documents"]:
            utility.helpers.logger.info(
                f'Beginning evaluation of "{document_dict["url"]}'
            )
            document_model = utility.document.Document.model_validate(document_dict)
            utility.helpers.logger.info(
                f'Converting document to images "{document_dict["url"]}'
            )
            utility.document.add_images_to_document(
                document_model, "/tmp/data", event["page_limit"]
            )
            utility.helpers.logger.info(f"Created {len(document_model.images)}")
            if event["evaluation_component"] == "summary":
                results = summary_eval_wrapper.evaluate(document_model)
                output.extend(results)
            if event["evaluation_component"] == "exception":
                results = asyncio.run(exception_eval_wrapper.evaluate(document_model))
                output.extend(results)
        if "output_google_sheet" in event.keys():
            utility.helpers.logger.info("Writing eval results to Google Sheet")
            utility.google_sheet.append_to_google_sheet(output, local_mode)
            return {
                "statusCode": 200,
                "body": "Wrote evaluation results to Google Sheet.",
            }
        elif "output_s3_bucket" in event.keys():
            if local_mode:
                raise RuntimeError(
                    "Local development is not supported S3 dumping mode. Do not include the `output_s3_bucket` event key."
                )
            utility.helpers.logger.info(
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
            utility.helpers.logger.info("Dumping results into Lambda return")
            return {"statusCode": 200, "body": output}
    except ValidationError as e:
        message = f"Invalid document supplied to event: {str(e)}"
        return {"statusCode": 500, "body": message}
    except Exception as e:
        output = str(e)
        if local_mode:
            output = traceback.format_exc()
        utility.helpers.logger.error(f"Error during execution: {output}")
        return {"statusCode": 500, "body": output}
