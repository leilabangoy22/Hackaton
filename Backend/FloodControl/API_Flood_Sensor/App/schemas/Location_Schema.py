from pydantic import BaseModel
from typing import Optional, List

class Location_SchemaBase(BaseModel):
    location_id: Optional[int]
    latitude: str
    longitude: str

    def to_dict(self):
        return {
            "Location ID": self.location_id,
            "Latitude": self.latitude,
            "longitude": self.longitude
        }

    class Config:
        from_attributes = True

class Location_SchemaBaseResponse(BaseModel):
    status_code: int
    data: Optional[Location_SchemaBase] = None

class Location_SchemaBaseListResponse(BaseModel):
    status_code: int
    data: List[Location_SchemaBase] = []
