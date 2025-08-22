import json
from typing import List

from evaluation.utility.helpers import get_secret, logger
from google.oauth2.service_account import Credentials
from googleapiclient.discovery import build

GOOGLE_EVAL_SERVICE_ACCOUNT_CREDS = "asap-pdf/{AWS_ENV}/GOOGLE_SERVICE_ACCOUNT"
GOOGLE_EVAL_SHEET_ID = "asap-pdf/{AWS_ENV}/GOOGLE_SHEET_ID_EVALUATION"
RANGE_NAME = "Results!A:L"
SCOPES = ["https://www.googleapis.com/auth/spreadsheets"]


def append_to_google_sheet(results: List[dict], local_mode: bool, aws_env: str) -> None:

    creds_json = json.loads(
        get_secret(GOOGLE_EVAL_SERVICE_ACCOUNT_CREDS, local_mode, aws_env)
    )
    sheet_id = get_secret(GOOGLE_EVAL_SHEET_ID, local_mode, aws_env)

    logger.info(f"Appending results to {sheet_id} range {RANGE_NAME}...")

    # Create credentials from the service account info
    credentials = Credentials.from_service_account_info(creds_json, scopes=SCOPES)
    service = build("sheets", "v4", credentials=credentials)
    data = []
    for result in results:
        result_values = []
        for value in result.values():
            if type(value) in (dict, list):
                result_values.append(json.dumps(value))
            else:
                result_values.append(value)
        data.append(result_values)

    body = {"values": data}
    try:
        service.spreadsheets().values().append(
            spreadsheetId=sheet_id, range=RANGE_NAME, valueInputOption="RAW", body=body
        ).execute()
    except Exception as e:
        # Add some additional context to the Google Sheet exception.
        raise RuntimeError(f"Error appending to Google sheet: {str(e)}")
