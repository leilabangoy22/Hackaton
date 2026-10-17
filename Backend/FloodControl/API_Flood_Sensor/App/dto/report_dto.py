from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime

class Report_SchemaBase(BaseModel):
    report_id: Optional[int]
    location_id: Optional[int]
    title: str
    flood_level_warnings: Optional[tuple[int,int,int]] = None
    flood_height: float
    explanation: Optional[str]
    response_status: Optional[str]
    response_id: Optional[int]
    created_by: Optional[int]
    created_at: Optional[datetime]
    updated_by: Optional[str]
    updated_at: Optional[datetime]

    def to_dict(self):
        return {
            "Report ID": self.report_id,
            "Location ID": self.location_id,
            "Title": self.title,
            "Flood Level Warnings": self.flood_level_warnings,
            "Flood Height": self.flood_height,
            "Explanation": self.explanation,
            "Response Status": self.response_status,
            "Response ID": self.response_id,
            "Created By": self.created_by,
            "Created At": self.created_at,
            "Updated By": self.updated_by,
            "Updated At": self.updated_at
        }

    class Config: 
        from_attributes = True # Allow ORM (SQLModel) to map attributes automatically

class Report_SchemaBaseResponse(BaseModel):
    status_code: int
    data: Optional[Report_SchemaBase] = None


class Report_SchemaBaseListResponse(BaseModel):
    status_code: int
    data: List[Report_SchemaBase] = []
