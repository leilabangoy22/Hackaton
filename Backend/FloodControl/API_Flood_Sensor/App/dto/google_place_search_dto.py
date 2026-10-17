from typing import Optional
from pydantic import BaseModel

class GooglePlaceSearchQuery(BaseModel):
    query: str
    location: Optional[str] = None
    radius: Optional[float] = None
    key: Optional[str] = None


class RescuerLocation(BaseModel):
    report_id : int
    latitude : str
    longitude : str
    distance : float = None

class RescuerLocationresponse(BaseModel):
    latitude_rescuer : str
    longitude_rescuer : str
    latitude_report : Optional[str]
    longitude_report : Optional[str]
    distance : float
    time_arrival : Optional[str] # seconds

class RescueLocationResponseBase(BaseModel):
    status_code :int 
    data : Optional[RescuerLocationresponse] = None