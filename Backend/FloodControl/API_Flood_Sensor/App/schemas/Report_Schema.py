from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime

# class Report_Schema(BaseModel):
#     location_id : int
#     title : str
#     flood_height : int  = Field(..., ge=0, description="Must Be Greater Than 0")
#     explanation : Optional[str]

class AddResponse_Schema(BaseModel):
    report_id : int
    response_id : int
    severity : str
    rescue_personnel_id : int
    assigned_to : int
    report_status : str
    response_status : str

class Report_SchemaBase(BaseModel):
    report_id: Optional[int] = None
    location_id: Optional[int]
    user_id : int
    user_phone_number : Optional[str] = None
    dispatcher_id : Optional[int] = None
    dispatcher_phone_number : Optional[str] = None
    user_name : Optional[str] = None
    severity : Optional[str] = None
    rescue_personnel_id : Optional[int] = None
    assigned_to : Optional[int] = None
    title: str
    flood_height: float = Field(..., ge=0, description="Must Be Greater Than 0")
    explanation: Optional[str]
    response_status: Optional[str]
    response_id: Optional[int] = None
    report_status : Optional[str] = None
    created_by: Optional[str]
    created_at: Optional[datetime]
    updated_by: Optional[str]
    updated_at: Optional[datetime]

    def to_dict(self):
        return {
            "Report ID": self.report_id,
            "Location ID": self.location_id,
            "User Id" : self.user_id,
            "User Name" : self.user_name,
            "User Contact Info" : self.user_phone_number,
            "Dispatcher Id" : self.dispatcher_id,
            "Dispatcher Contact Info" : self.dispatcher_phone_number,
            "Severity" : self.severity,
            "Title": self.title,
            "Flood Height": self.flood_height,
            "Explanation": self.explanation,
            "Response Status": self.response_status,
            "Assigned To" : self.assigned_to,   
            "Response ID": self.response_id,
            "Report Status" : self.report_status,
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
