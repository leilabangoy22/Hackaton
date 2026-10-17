from pydantic import BaseModel
from datetime import datetime
from typing import Optional, List

class Flood_SensorBase(BaseModel):
    data_id : Optional[int]
    data : Optional[float] # Exceeded Data -- eg. 20 cm above
    created_at : Optional[datetime]
    
    def to_dict(self):
        return{
            "Data Id" : self.data_id,
            "data" : self.data,
            "Created At" : self.created_at,
        }
    
    class Config:
        from_attributes = True

class Flood_SensorBaseResponse(BaseModel):
    status_id : int
    data : Optional[Flood_SensorBase] = None

class Flood_SensorBaseListResponse(BaseModel):
    status_id : int
    data : List[Flood_SensorBase] = []