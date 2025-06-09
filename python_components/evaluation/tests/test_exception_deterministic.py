from evaluation.exception import deterministic_score
from evaluation.utility.schema import Document

test_doc = Document(
    file_name="MINUTES%20December%202024.pdf",
    url="https://agr.georgia.gov/sites/default/files/documents/pest-control/MINUTES%20December%202024.pdf",
    category="Agenda",
    human_summary="Minutes for a December 12 2024 meeting of the Georgia Structural Pest Control Commission. During the meeting there were updates from the UGA Urban Entomology, Compliance and Enforcement, Certification and Training, among others.",
    created_date="2025-01-08 14:11:03",
    modification_date="2025-01-08 14:11:05",
    human_exception={"is_archival": True, "is_application": False},
    ai_exception={
        "is_archival": False,
        "why_archival": "While this document was used for meeting minutes for an event that occurred in the past, there is no indication it is kept for reference only or that it is stored in a special archival section.",
        "is_application": False,
    },
)


def test_creation_date_fuzzy_search():
    doc = test_doc.model_copy(deep=True)

    result = deterministic_score.evaluate_created_date(
        doc.created_date, doc.ai_exception["why_archival"]
    )
    assert type(result) is dict
    assert result["score"] == 0
    assert result["reason"] == "Created date was not found in explanation."

    doc.ai_exception[
        "why_archival"
    ] += " The document was created on December 12 2024, which is recent history."
    result = deterministic_score.evaluate_created_date(
        doc.created_date, doc.ai_exception["why_archival"]
    )
    assert result["score"] == 0
    assert result["reason"] == "Created date was not found in explanation."

    doc.ai_exception[
        "why_archival"
    ] += " The document was created on January 2025, which is recent history."
    result = deterministic_score.evaluate_created_date(
        doc.created_date, doc.ai_exception["why_archival"]
    )
    assert result["score"] == 1
    assert result["reason"] == "Created date was found in explanation."

    doc.created_date = "bad"
    result = deterministic_score.evaluate_created_date(
        doc.created_date, doc.ai_exception["why_archival"]
    )
    assert result["score"] == 0
    assert result["reason"] == "Provided created date, bad was malformed."


def test_creation_date_spacy():
    doc = test_doc.model_copy(deep=True)

    result = deterministic_score.evaluate_created_date_spacy(
        doc.created_date, doc.ai_exception["why_archival"]
    )
    assert result["score"] == 0
    assert result["reason"] == "Created date was not found in explanation."

    doc.ai_exception[
        "why_archival"
    ] += " The document was created on October 12 2024, which is recent history."
    result = deterministic_score.evaluate_created_date_spacy(
        doc.created_date, doc.ai_exception["why_archival"]
    )
    assert result["score"] == 0
    assert result["reason"] == "Created date was not found in explanation."

    doc.ai_exception[
        "why_archival"
    ] += " The document was created on December 2024, which is recent history."
    result = deterministic_score.evaluate_created_date_spacy(
        doc.created_date, doc.ai_exception["why_archival"]
    )
    assert result["score"] == 1
    assert result["reason"] == "Created date was found in explanation."


def test_updated_date_spacy():
    doc = test_doc.model_copy(deep=True)

    result = deterministic_score.evaluate_modified_date_spacy(
        doc.modification_date, doc.ai_exception["why_archival"]
    )
    assert result["score"] == 1
    assert (
        result["reason"]
        == "Modified date was not found in explanation or was within expected date range."
    )

    doc.ai_exception[
        "why_archival"
    ] += " The document was created on October 12 2022, which is recent history."
    result = deterministic_score.evaluate_modified_date_spacy(
        doc.modification_date, doc.ai_exception["why_archival"]
    )
    assert result["score"] == 0
    assert (
        result["reason"]
        == "Modified date was found in explanation. It's a year beyond the created date or it mentions any date beyond the compliance deadline."
    )

    # Test multiple dates
    doc.ai_exception[
        "why_archival"
    ] += " The document was created on December 2024, which is recent history."
    result = deterministic_score.evaluate_modified_date_spacy(
        doc.modification_date, doc.ai_exception["why_archival"]
    )
    assert result["score"] == 0
    assert (
        result["reason"]
        == "Modified date was found in explanation. It's a year beyond the created date or it mentions any date beyond the compliance deadline."
    )

    # Wipe out previous mutations.
    doc = test_doc.model_copy(deep=True)
    doc.ai_exception[
        "why_archival"
    ] += " The document was created on December 2024, which is recent history."
    result = deterministic_score.evaluate_modified_date_spacy(
        doc.modification_date, doc.ai_exception["why_archival"]
    )
    assert result["score"] == 1
    assert (
        result["reason"]
        == "Modified date was not found in explanation or was within expected date range."
    )


def test_correctness():
    doc = test_doc.model_copy(deep=True)

    result = deterministic_score.evaluate_correctness(
        doc.human_exception["is_archival"], doc.ai_exception["is_archival"]
    )
    assert result["score"] == 0

    result = deterministic_score.evaluate_correctness(
        doc.human_exception["is_application"], doc.ai_exception["is_application"]
    )
    assert result["score"] == 1
