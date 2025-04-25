import os
import json

from deepeval.models import MultimodalGeminiModel
from pydantic import ValidationError

from evaluation import summary, utility
from evaluation.utility.helpers import logger



examples = [
    ["MINUTES%20December%202024.pdf",
     "https://agr.georgia.gov/sites/default/files/documents/pest-control/MINUTES%20December%202024.pdf", "Agenda"],
    # ["VA S.A.V.E. Training One-Pager", "https://www.mentalhealth.va.gov/suicide_prevention/docs/VA_SAVE_Training.pdf",
    #  "Brochure"],
    # ["atlanta-market-map.pdf",
    #  "https://agr.georgia.gov/sites/default/files/documents/agritourism/atlanta-market-map.pdf", "Diagram"],
    # ["Microsoft Word - One-page reasonable accommodation form.docx",
    #  "https://www.austintexas.gov/sites/default/files/files/HR/One-page_reasonable_accommodation_form.pdf", "Form"],
    # ["2013.07.16_PlanningCommission.pdf", "http://www.slcdocs.com/attorney/COI/2013.07.16_PlanningCommission.pdf",
    #  "Letter"],
    # ["Font Size:  12", "https://services.austintexas.gov/edims/document.cfm?id=446835", "Notice"],
    # ["08.14.15.14.pdf",
    #  "https://nathandeal.georgia.gov/sites/nathandeal.georgia.gov/files/related_files/document/08.14.15.14.pdf",
    #  "Policy"],
    # ["5.b-Vacancies-on-Boards-and-Commissions.pdf",
    #  "https://storage.googleapis.com/proudcity/sanrafaelca/uploads/2021/07/5.b-Vacancies-on-Boards-and-Commissions.pdf",
    #  "Report"],
    # ["Microsoft PowerPoint - Council Workession Update on Bond Development 4-3-17 FINAL.pptx",
    #  "https://services.austintexas.gov/edims/document.cfm?id=274486", "Slides"],
    # ["July-2016-WCE-Salary-Schedule.pdf",
    #  "https://storage.googleapis.com/proudcity/sanrafaelca/uploads/2016/09/July-2016-WCE-Salary-Schedule.pdf",
    #  "Spreadsheet"]
]

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
        #helpers.validate_event(event)
        logger.info("Event is valid")
        local_mode = os.environ.get("ASAP_LOCAL_MODE", False)
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
            summary.add_summary_to_document(document_model, "gemini-1.5-pro-latest")
            logger.info(f"Summarization complete.")
            result = summary.evaluation(document_model, model)
            output.append(result)
            logger.info(f"Evaluation complete.")
        if "asap_endpoint" in event.keys():
            logger.info("Writing eval results to Rails API")
            # todo write API endpoint and put a call here.
            return {
                "statusCode": 200,
                "body": "Successfully made document recommendation.",
            }
        else:
            logger.info("Dumping results into Lambda return")
            return {"statusCode": 200, "body": json.dumps(output)}
    except ValidationError as e:
        message = f'Invalid document supplied to event: {str(e)}'
        return {"statusCode": 500, "body": message}
    except Exception as e:
        return {"statusCode": 500, "body": str(e)}

