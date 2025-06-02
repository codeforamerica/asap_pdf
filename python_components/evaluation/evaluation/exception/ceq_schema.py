from typing import List, Optional, Literal
from pydantic import BaseModel, Field


class CEQVerdict(BaseModel):
    verdict: Literal["yes", "no", "idk"]
    reason: Optional[str] = Field(default=None)


class Verdicts(BaseModel):
    verdicts: List[CEQVerdict]


class Reason(BaseModel):
    reason: str
