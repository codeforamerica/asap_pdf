import datetime
import fnmatch
import re

import spacy
from dateutil import parser
from evaluation.utility.helpers import logger
from evaluation.utility.schema import Document

METRIC_VERSION = 2

DATE_FORMATS = (
    "*%Y%m%d*",  # "20240315"
    "*%m%d%Y*",  # "03152024"
    "*%m%Y*",  # "032024"
    "*%d%m%Y*",  # "15032024"
    "*%B%d%Y*",  # "march152024" (full month, lowercase)
    "*%b%d%Y*",  # "mar152024" (abbreviated month, lowercase)
    "*%d%B%Y*",  # "15march2024"
    "*%Y%m%d%H%M%S*",  # "20240315143000"
    "*%B%Y*",  # "march2024" (month year only)
    "*%b%Y*",  # "mar2024" (abbreviated month year)
    "*%d%B*",  # "15march" (day month, no year)
    "*%B%Y*",  # "march2024" (full month, lowercase)
)

COMPLIANCE_DATE_FORMATS = ["April 2026", "April 24, 2026", "April 24"]


def evaluate_archival_exception(document: Document) -> tuple[float, dict]:
    evaluations = {
        "created_date": max_created_date_evaluation(document),
        "modified_date": evaluate_modified_date_spacy(
            document.modification_date, document.ai_exception["why_archival"]
        ),
        "correctness": evaluate_correctness(
            document.human_exception["is_archival"],
            document.ai_exception["is_archival"],
        ),
    }
    success_count = 0
    for evaluation in evaluations.values():
        success_count += evaluation["score"]
    score = success_count / len(evaluations)
    return score, evaluations


def evaluate_application_exception(document: Document) -> tuple[float, dict]:
    evaluations = {
        "correctness": evaluate_correctness(
            document.human_exception["is_application"],
            document.ai_exception["is_application"],
        ),
    }
    success_count = 0
    for evaluation in evaluations.values():
        success_count += evaluation["score"]
    score = success_count / len(evaluations)
    return score, evaluations


def max_created_date_evaluation(document: Document) -> dict:
    fuzzy_match = evaluate_created_date(
        document.created_date, document.ai_exception["why_archival"]
    )
    ner = evaluate_created_date_spacy(
        document.created_date, document.ai_exception["why_archival"]
    )
    if ner["score"] >= fuzzy_match["score"]:
        return ner
    return fuzzy_match


def extract_year_month(date_string):
    date_parsed = parser.parse(date_string)
    drop_day = date_parsed.strftime("%Y-%m")
    return datetime.datetime.strptime(drop_day, "%Y-%m")


def evaluate_created_date(created_date: str, text: str) -> dict:
    logger.info("Evaluating creation date via fuzzy search...")
    normalized_text = text.lower()
    normalized_text = re.sub(r"[^a-zA-Z0-9]", "", normalized_text)
    logger.info("Text normalized...")
    try:
        creation_dt = datetime.datetime.strptime(created_date, "%Y-%m-%d %H:%M:%S")
    except ValueError:
        return {
            "score": 0,
            "reason": f"Provided created date, {created_date} was malformed.",
        }
    logger.info("Assessing date strings...")
    for date_format in DATE_FORMATS:
        if fnmatch.fnmatch(normalized_text, creation_dt.strftime(date_format).lower()):
            return {"score": 1, "reason": "Created date was found in explanation."}
    return {"score": 0, "reason": "Created date was not found in explanation."}


def evaluate_created_date_spacy(created_date: str, text: str) -> dict:
    logger.info("Evaluating creation date via spacy search...")
    nlp = spacy.load("en_core_web_sm")
    doc = nlp(text)
    dates = [ent.text for ent in doc.ents if ent.label_ == "DATE"]
    year_month = extract_year_month(created_date)
    for date_found in dates:
        try:
            date_year_month = extract_year_month(date_found)
            # Found date in text within a month of document's created date
            if abs(date_year_month - year_month).days <= 31:
                return {"score": 1, "reason": "Created date was found in explanation."}
        except parser.ParserError:
            continue
    return {"score": 0, "reason": "Created date was not found in explanation."}


def evaluate_modified_date_spacy(created_date: str, text: str) -> dict:
    logger.info("Evaluating modification date via spacy search...")
    nlp = spacy.load("en_core_web_sm")
    doc = nlp(text)
    dates = [ent.text for ent in doc.ents if ent.label_ == "DATE"]
    compliance_deadline = parser.parse("2026-04-24")
    year_month = extract_year_month(created_date)
    for date_found in dates:
        try:
            date_object = extract_year_month(date_found)
            if (date_object == compliance_deadline) or (
                date_found in COMPLIANCE_DATE_FORMATS
            ):
                # If this date is the compliance deadline, then continue to look over other dates.
                continue
            if (abs(date_object - year_month).days > 365) or (
                date_object > compliance_deadline
            ):
                return {
                    "score": 0,
                    "reason": "Modified date was found in explanation. It's a year beyond the created date or it mentions any date beyond the compliance deadline.",
                }
        except parser.ParserError:
            continue
    return {
        "score": 1,
        "reason": "Modified date was not found in explanation or was within expected date range.",
    }


def evaluate_correctness(human_result: bool, ai_result: bool) -> dict:
    logger.info("Evaluating correctness...")
    if human_result == ai_result:
        return {"score": 1, "reason": f"Human and AI results match {ai_result}."}
    return {
        "score": 0,
        "reason": f"Human and AI results do not match, {human_result} and {ai_result} respectively.",
    }
