from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime

class Response_SchemaBase(BaseModel):    
    response_id : Optional[int]
    rescue_personel_id : int
    response_details : str
    created_by : Optional[str]
    created_at : Optional[datetime]
    updated_by : Optional[str]
    updated_at : Optional[datetime]

    def to_dict(self):
        return{
            "Response Id" : self.response_id,
            "Rescue Personel Id" : self.rescue_personel_id,
            "Response Details" : self.response_details,
            "Created By" : self.created_by,
            "Created At" : self.created_at,
            "Updated By" : self.updated_by,
            "Updated At" : self.updated_at,
            
        }
    
    class Config:
        from_attributes = True

class Response_SchemaBaseResponse(BaseModel):
    status_code : int
    data : Optional[Response_SchemaBase] = None

class Response_SchemaBaseListResponse(BaseModel):
    status_code : int
    data : List[Response_SchemaBase] = []