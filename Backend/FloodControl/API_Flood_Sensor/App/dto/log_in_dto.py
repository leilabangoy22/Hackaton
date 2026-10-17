from pydantic import BaseModel, Field
from typing import Optional

class Log_InSchemaBase(BaseModel):
    name : str
    password : str = None

class Update_LocationBase(BaseModel):
    location_id : int

class IsActiveBase(BaseModel):
    isActive : Optional[bool] = Field(default=None, description="Please Input Only Active or Inactive, For The Dispatcher To Know If Its Under Your Work Time")

    def to_dict(self):
        return{
            "Is Active" : self.isActive
        }
    
    class Config:
        from_attributes = True

class IsActiveBaseSTR(BaseModel):
    isActiveSTR : Optional[str]
    def to_dict(self):
        return{
            "Is Active" : self.isActiveSTR
        }
    class Config:
        from_attributes = True

class IsActiveBaseResponse(BaseModel):
    status_code : int
    data : Optional[IsActiveBaseSTR] = None

class User_UpdateDisplay_SchemaBase(BaseModel):
    name : Optional[str] = Field(default=None)
    email : Optional[str] = Field(default=None)
    mobile_number : Optional[str] = Field(default=None)
    
    def to_dict(self):
        return{
            "Name" : self.name,
            "Email" : self.email,
            "Mobile Number" : self.mobile_number,
        }
    
    class Config():
        from_attributes = True  # to extract data fro obj in routers later

class User_UpdateDisplay_SchemaBaseResponse(BaseModel):
    status_code : int
    data : Optional[User_UpdateDisplay_SchemaBase] = None

class Change_PasswordBase(BaseModel):
    old_password : str
    new_password : str
    
    def to_dict(self):
        return{
            "Old Password" : self.old_password,
            "New Password" : self.new_password
        }
    
    class Config:
        from_attributes = True