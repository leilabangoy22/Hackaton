from pydantic import BaseModel
from typing import Optional, List

class User_SchemaBase(BaseModel):
    user_id : Optional[int]
    name : Optional[str]
    email : Optional[str]
    password : Optional[str]
    mobile_number : Optional[str]
    role : str
    location_id : Optional[int] = None

    def to_dict(self):
        return{
            "User ID" : self.user_id,
            "Name" : self.name,
            "Email" : self.email,
            "Mobile Number" : self.mobile_number,
            "Role" : self.role,
            "Location Id" : self.location_id
        }
    
    class Config():
        from_attributes = True  # to extract data fro obj in routers later

class User_Display_SchemaBase(BaseModel):
    user_id : Optional[int]
    name : Optional[str]
    email : Optional[str]
    mobile_number : Optional[str]
    role : str
    location_id : Optional[int] = None
    
    def to_dict(self):
        return{
            "User ID" : self.user_id,
            "Name" : self.name,
            "Email" : self.email,
            "Mobile Number" : self.mobile_number,
            "Role" : self.role,
            "Location Id" : self.location_id,
            "Message" : f"Welcome {self.name}"
        }
    
    class Config():
        from_attributes = True  # to extract data fro obj in routers later


class User_Display_SchemaBaseResponse(BaseModel):
    status_code : int
    data : Optional[User_Display_SchemaBase] = None

class User_Display_SchemaBaseListResponse(BaseModel):
    status_code : int 
    data : List[User_Display_SchemaBase] = []