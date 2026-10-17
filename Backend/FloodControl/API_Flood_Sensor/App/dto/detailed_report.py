from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime

# <class> detailed_responseBase
class detailed_responseBase(BaseModel):
    # <user section>
    user_id: Optional[int]
    name: Optional[str]
    email: Optional[str]
    mobile_number: Optional[str]
    role: str

    # <report section>
    report_id: Optional[int]
    location_id_link: Optional[int]
    user_id_link:Optional[int]
    title: str
    flood_height: int = Field(..., ge=0, description="Must Be Greater Than 0")
    explanation: Optional[str]
    response_status: Optional[str]
    report_created_by: Optional[str]
    report_created_at: Optional[datetime]
    report_updated_by: Optional[str]
    report_updated_at: Optional[datetime]
    
    location_id: Optional[int]
    city: str
    barangay: str
    street: str
    latitude: Optional[str]
    longitude: Optional[str]

    # <response section>
    response_id: Optional[int]
    response_details: str
    response_created_by: Optional[int]
    response_created_at: Optional[datetime]
    response_updated_by: Optional[str]
    response_updated_at: Optional[datetime]

    # <rescue section>
    rescue_personel_id: Optional[int]
    rescuer_id: List[int]
    response_link_id: int  # renamed from duplicate response_id to avoid conflict

    def to_dict(self):
        return {
            # User info
            "User ID": self.user_id,
            "Name": self.name,
            "Email": self.email,
            "Mobile Number": self.mobile_number,
            "Role": self.role,

            # Report info
            "Report ID": self.report_id,
            "Location ID": self.location_id,
            "User Id" : self.user_id_link,
            "Title": self.title,
            "Flood Height": self.flood_height,
            "Explanation": self.explanation,
            "Response Status": self.response_status,
            "Report Created By": self.report_created_by,
            "Report Created At": self.report_created_at,
            "Report Updated By": self.report_updated_by,
            "Report Updated At": self.report_updated_at,

            # Location Info
            "Location Id" : self.location_id,
            "City" : self.city,
            "Barangay" : self.barangay,
            "Street" : self.street,
            "Latitude" : self.latitude,
            "longitude" : self.longitude,
            
            # Response info
            "Response ID": self.response_id,
            "Response Details": self.response_details,
            "Response Created By": self.response_created_by,
            "Response Created At": self.response_created_at,
            "Response Updated By": self.response_updated_by,
            "Response Updated At": self.response_updated_at,

            # Rescue info
            "Rescue Personel ID": self.rescue_personel_id,
            "Rescuer IDs": self.rescuer_id,
            "Response Link ID": self.response_link_id
        }

    class Config:
        from_attributes = True  # allows ORM models to be converted to Pydantic models

class detailed_responseBaseListResponse(BaseModel):
    status_code : int
    data : Optional[detailed_responseBase] = []