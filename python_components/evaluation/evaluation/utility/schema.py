from typing import Optional

from pydantic import BaseModel


class Document(BaseModel):
    file_name: str
    url: str
    category: str
    human_summary: Optional[str] = None
    ai_summary: Optional[str] = None
    images: Optional[list] = None
    created_date: Optional[str] = None
    modification_date: Optional[str] = None
    ai_exception: Optional[dict] = None
    human_exception: Optional[dict] = None

    def llm_context(self):
        return [
            f"Created Date: {self.created_date}",
            f"Modified Date: {self.modification_date}",
            f"Category: {self.category}",
            f"Url: {self.url}",
        ]


class Result(BaseModel):
    branch_name: str
    commit_sha: str
    file_name: str
    delta: Optional[int] = 0
    metric_name: str
    metric_version: float
    score: float
    reason: Optional[str] = None
    details: Optional[dict] = None
    inference_model: Optional[str] = None
    evaluation_model: Optional[str] = None