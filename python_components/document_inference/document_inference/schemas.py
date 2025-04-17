from typing import Optional

from pydantic import BaseModel, Field, model_serializer
from pydantic.json_schema import SkipJsonSchema


class DocumentSummarySchema(BaseModel):
    summary: str = Field(
        description="A two to three sentence summary of the provided document."
    )


class DocumentRecommendation(BaseModel):
    is_individualized: SkipJsonSchema[bool] = None
    why_individualized: SkipJsonSchema[str] = None
    is_individualized_confidence: SkipJsonSchema[float] = None
    is_archival: bool = Field(
        description="Whether the document meets exception 1: Archived Web Content Exception"
    )
    why_archival: str = Field(
        description="An explanation of why the document meets or does not meet exception 1: Archived Web Content Exception"
    )
    is_archival_confidence: float = Field(
        description="Percentage representing how confident you are about whether the document meets exception 1: Archived Web Content Exception",
        ge=0,
        le=1
    )
    is_application: bool = Field(
        description="Whether the document meets exception 2: Preexisting Conventional Electronic Documents Exception"
    )
    why_application: str = Field(
        description="An explanation of why the document meets or does not meet exception 2: Preexisting Conventional Electronic Documents Exception"
    )
    is_application_confidence: float = Field(
        description="Percentage representing how confident you are about whether the document meets exception 2: Preexisting Conventional Electronic Documents Exception",
        ge=0,
        le=1
    )
    is_third_party: bool = Field(
        description="Whether the document meets exception 3: Content Posted by Third Parties Exception"
    )
    why_third_party: str = Field(
        description="An explanation of why the document meets or does not meet exception 3: Content Posted by Third Parties Exception"
    )
    is_third_party_confidence: float = Field(
        description="Percentage representing how confident you are about whether the document meets exception 3: Content Posted by Third Parties Exception",
        ge=0,
        le=1
    )
