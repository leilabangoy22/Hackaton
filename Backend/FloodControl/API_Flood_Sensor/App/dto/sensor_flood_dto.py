from pydantic import BaseModel
from datetime import datetime
from typing import Optional, List

class Flood_SensorBase(BaseModel):
    data_id : Optional[int] = None
    flood_data : Optional[float] # Exceeded Data -- eg. 20 cm above
    created_at : Optional[datetime]
    
    def to_dict(self):
        return{
            "Data Id" : self.data_id,
            "Flood Data" : self.flood_data,
            "Created At" : self.created_at,
        }
    
    class Config:
        from_attributes = True

class Flood_SensorBaseList(BaseModel):
    status_code : int
    data: Optional[Flood_SensorBase] = None       # For DB entry
    datas: Optional[List[Flood_SensorBase]] = []  # For memory list
    
    def to_dict(self):
        return{
            "Status Code" : self.status_code,
            "Normal Record" : self.datas,
            "Exceeded Record" : self.data,
            
        }
    
    class Config:
        from_attributes = True
        orm_mode = True

class Flood_SensorBaseResponse(BaseModel):
    status_id : int
    data : Optional[Flood_SensorBase] = None

class Flood_SensorBaseListResponse(BaseModel):
    status_id : int
    data : List[Flood_SensorBase] = []