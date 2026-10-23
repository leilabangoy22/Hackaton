from pydantic import BaseModel
from typing import Optional


class grid_riskBase(BaseModel):
    grid_id: str
    latitude: float
    longitude: float
    risk_score: float

    class Config:
        from_attributes = True


class AIParamsResponseDTO(BaseModel):
    high_risk_areas: list[grid_riskBase]
    safest_area: Optional[grid_riskBase] = None
    ai_assessment: str

    class Config:
        from_attributes = True