from typing import Optional

from pydantic import BaseModel, Field
from pydantic.json_schema import SkipJsonSchema
from llm.models import Usage


class DocumentSummarySchema(BaseModel):
    summary: str = Field(
        description="A two to three sentence summary of the provided document."
    )
    inference_model: SkipJsonSchema[str] = ""
    usage: SkipJsonSchema[Optional[Usage]] = None


class DocumentRecommendation(BaseModel):
    is_archival: bool = Field(
        description="Whether the document meets exception 1: Archived Web Content Exception"
    )
    why_archival: str = Field(
        description="An explanation of why the document meets or does not meet exception 1: Archived Web Content Exception"
    )
    is_application: bool = Field(
        description="Whether the document meets exception 2: Preexisting Conventional Electronic Documents Exception"
    )
    why_application: str = Field(
        description="An explanation of why the document meets or does not meet exception 2: Preexisting Conventional Electronic Documents Exception"
    )
    inference_model: SkipJsonSchema[str] = ""
    usage: SkipJsonSchema[Optional[Usage]]  = None
