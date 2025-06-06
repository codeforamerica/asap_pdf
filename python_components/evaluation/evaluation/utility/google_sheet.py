from typing import List

import json

from google.oauth2.service_account import Credentials
from googleapiclient.discovery import build

from evaluation.utility.helpers import get_secret, logger


GOOGLE_EVAL_SERVICE_ACCOUNT_CREDS = "/asap-pdf/production/GOOGLE_SERVICE_ACCOUNT-20250605155250934400000001"
GOOGLE_EVAL_SHEET_ID = "/asap-pdf/production/GOOGLE_SHEET_ID_EVALUATION-20250605155250934400000003"
RANGE_NAME="Results!A2:L2"
SCOPES = ['https://www.googleapis.com/auth/spreadsheets']


def append_to_google_sheet(results: List[dict], local_mode: bool) -> None:

    creds_json = json.loads(get_secret(GOOGLE_EVAL_SERVICE_ACCOUNT_CREDS, local_mode))
    sheet_id = get_secret(GOOGLE_EVAL_SHEET_ID, local_mode)

    logger.info(f"Appending results to {sheet_id} range {RANGE_NAME}...")

    # Create credentials from the service account info
    credentials = Credentials.from_service_account_info(
        creds_json, scopes=SCOPES)
    service = build('sheets', 'v4', credentials=credentials)

    data = []
    for result in results:
        result_values = []
        for value in result.values():
            if type(value) in (dict, list):
                result_values.append(json.dumps(value))
            else:
                result_values.append(value)
        data.append(result_values)

    body = {
        'values': data
    }
    try:
        service.spreadsheets().values().append(
            spreadsheetId=sheet_id, range=RANGE_NAME,
            valueInputOption='RAW', body=body
        ).execute()
    except Exception as e:
        logger.info(f"Error appending to Google sheet: {str(e)}")

