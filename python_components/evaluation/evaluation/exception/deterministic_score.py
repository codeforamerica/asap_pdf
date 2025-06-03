import datetime
import fnmatch
import re

import spacy
from dateutil import parser
from evaluation.utility.document import Document

date_formats = (
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

spacy.cli.download("en_core_web_sm")


def evaluate_archival_exception(document: Document) -> tuple[float, dict]:
    evaluations = {
        "created_date": evaluate_created_date(
            document.created_date, document.ai_exception["why_archival"]
        ),
        "created_date_ner": evaluate_created_date_spacey(
            document.created_date, document.ai_exception["why_archival"]
        ),
        "modified_date_ner": evaluate_modified_date_spacey(
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


def extract_year_month(date_string):
    date_parsed = parser.parse(date_string)
    drop_day = date_parsed.strftime("%Y-%m")
    return datetime.datetime.strptime(drop_day, "%Y-%m")


def evaluate_created_date(created_date: str, text: str) -> dict:
    normalized_text = text.lower()
    normalized_text = re.sub(r"[^a-zA-Z0-9]", "", normalized_text)
    creation_dt = datetime.datetime.strptime(created_date, "%Y-%m-%d %H:%M:%S")
    for date_format in date_formats:
        if fnmatch.fnmatch(normalized_text, creation_dt.strftime(date_format).lower()):
            return {"score": 1, "reason": "Created date was found in explanation."}
    return {"score": 0, "reason": "Created date was not found in explanation."}


def evaluate_created_date_spacey(created_date: str, text: str) -> dict:
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


def evaluate_modified_date_spacey(modified_date: str, text: str) -> dict:
    nlp = spacy.load("en_core_web_sm")
    doc = nlp(text)
    dates = [ent.text for ent in doc.ents if ent.label_ == "DATE"]
    compliance_deadline = parser.parse("2026-04-24")
    year_month = extract_year_month(modified_date)
    for date_found in dates:
        try:
            date_object = parser.parse(date_found)
            if (abs(date_object - year_month).days > 365) or (
                date_object > compliance_deadline
            ):
                return {
                    "score": 0,
                    "reason": "Modified date was found in explanation. It's a year beyond the created date or it mentions any date beyond the compliance deadline.",
                }
        except parser.ParserError:
            continue
    return {"score": 1, "reason": "Modified date was not found in explanation."}


def evaluate_correctness(human_result: bool, ai_result: bool) -> dict:
    if human_result == ai_result:
        return {"score": 1, "reason": f"Human and AI results match {ai_result}."}
    return {
        "score": 0,
        "reason": f"Human and AI results do not match, {human_result} and {ai_result} respectively.",
    }
