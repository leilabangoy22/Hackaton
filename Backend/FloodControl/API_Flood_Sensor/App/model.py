from sqlmodel import SQLModel, Field, Column, JSON
from typing import Optional, List
from datetime import datetime


# ---- USER TABLE
class User(SQLModel, table = True):
    user_id : Optional[int] = Field(default = None, primary_key= True, nullable=False, index= True)
    email : str = Field(nullable=True, max_length=100)
    password_hash : Optional[str] = Field(nullable=False, max_length=200)
    name : str = Field(nullable=False, max_length=200)
    mobile_number : str = Field(nullable=True, max_length=12)
    isActive : Optional[bool] = Field(nullable=False)
    role : Optional[str] = Field(nullable=False)
    location_id :Optional[int] = Field(nullable=True)

class Flood_Sensor(SQLModel, table = True):
    data_id : Optional[int] = Field(default = None, primary_key= True, nullable=False, index= True)
    data : Optional[float] = Field(nullable=False), 
    created_at : Optional[datetime] = Field(nullable=False)

class Location(SQLModel, table = True):
    location_id: Optional[int] = Field(default=None, primary_key=True, nullable=False, index= True)
    latitude : str = Field(nullable=False)
    longitude : str = Field(nullable=False)

class Report(SQLModel, table = True):
    report_id: Optional[int] = Field(default=None, primary_key=True, nullable=False, index=True)
    location_id : int = Field(nullable=False)
    user_id : int = Field(nullable=False)
    dispatcher_id : int = Field(nullable=True)
    severity : Optional[str] = Field(nullable=True)
    title : str = Field(nullable=False, max_length=200)
    flood_height : float = Field(nullable=False)
    explanation : str = Field(nullable=True, max_length=500)
    response_status : str = Field(nullable=False)
    response_id : Optional[int] = Field(nullable=True)
    rescue_personnel_id : Optional[int] = Field(nullable=True)
    assigned_to : Optional[int] = Field(nullable=True)
    report_status : Optional[str] = Field(nullable=True)
    created_by : Optional[str] = Field(nullable=False)
    created_at : Optional[datetime] = Field(nullable=False)
    updated_by : Optional[str] = Field(nullable=False)
    updated_at : Optional[datetime] = Field(nullable=False)

class Response(SQLModel,  table = True):
    response_id : Optional[int] = Field(default=None, primary_key=True, nullable=False, index=True)
    rescue_personel_id : int = Field(nullable=False)
    response_details : str = Field(nullable=True, max_length=500)
    created_by : Optional[str] = Field(nullable=False)
    created_at : Optional[datetime] = Field(nullable=False)
    updated_by : Optional[str] = Field(nullable=False)
    updated_at : Optional[datetime] = Field(nullable=False)

class Rescue_Personel(SQLModel, table = True):
    rescue_personel_id : Optional[int] = Field(default=None, primary_key=True, nullable=False, index=True)  
    rescuer_id : List[int] = Field(sa_column=Column(JSON, nullable=True))