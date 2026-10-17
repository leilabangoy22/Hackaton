from pydantic import BaseModel
from typing import Optional, List

class Rescuer_ListBase(BaseModel):
    user_id : Optional[int]
    name : Optional[str]
    email : Optional[str]
    password : Optional[str]
    mobile_number : Optional[str]
    isActive : Optional[str]
    role : str

    def to_dict(self):
        return{
            "User ID" : self.user_id,
            "Name" : self.name,
            "Email" : self.email,
            "Mobile Number" : self.mobile_number,
            "Active Status" : self.isActive,
            "Role" : self.role
        }
    
    class Config():
        from_attributes = True  # to extract data fro obj in routers later

class Rescuer_ListBaseListResponse(BaseModel):
    status_code : int
    data : List[Rescuer_ListBase] = []