from pydantic import BaseModel, Field
from typing import Optional

class CellRisk(BaseModel):
    grid_id: str
    risk_score: float = Field(ge=0, le=100)
    risk_reason: str


class GeminiRiskResponse(BaseModel):
    assessments: list[CellRisk]
    ai_assessment: str
