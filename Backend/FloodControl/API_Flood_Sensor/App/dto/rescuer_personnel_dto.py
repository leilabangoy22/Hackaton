from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime

class Get_RescuePersonnel_(BaseModel):
    user_id : Optional[int]
    name : Optional[str]
    mobile_number : Optional[str]
    role : str
    
    def to_dict(self):
        return{
            "User Id" : self.user_id,
            "Name" : self.name,
            "Mobile Number" : self.mobile_number,
            "Role" : self.role
        }
    
    class Config:
        from_attributes = True

class Get_RescuePersonnel_ListResponse(BaseModel):
    status_code : int
    leader : Optional[Get_RescuePersonnel_] = None
    members : List[Get_RescuePersonnel_] = []