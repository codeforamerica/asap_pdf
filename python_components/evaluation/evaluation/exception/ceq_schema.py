from typing import List, Literal, Optional

from pydantic import BaseModel, Field


class CEQVerdict(BaseModel):
    verdict: Literal["yes", "no", "idk"]
    reason: Optional[str] = Field(default=None)


class Verdicts(BaseModel):
    verdicts: List[CEQVerdict]
