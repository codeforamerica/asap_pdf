from pydantic import BaseModel, Field

"""
Holds our Pydantic model for structured output.
"""

class DocumentEligibility(BaseModel):
    is_archival: bool = Field(description="Whether the document meets exception 1: Archived Web Content Exception")
    why_archival: str = Field(description="An explanation of why the document meets or does not meet exception 1: Archived Web Content Exception")
    is_application: bool = Field(description="Whether the document meets exception 2: Preexisting Conventional Electronic Documents Exception")
    why_application: str = Field(description="An explanation of why the document meets or does not meet exception 2: Preexisting Conventional Electronic Documents Exception")
    is_third_party: bool = Field(description="Whether the document meets exception 3: Content Posted by Third Parties Exception")
    why_third_party: str = Field(description="An explanation of why the document meets or does not meet exception 3: Content Posted by Third Parties Exception")