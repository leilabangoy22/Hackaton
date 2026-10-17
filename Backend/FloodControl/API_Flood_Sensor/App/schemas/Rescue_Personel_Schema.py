from pydantic import BaseModel
from typing import Optional, List

class Rescue_Personel_SchemaBase(BaseModel):
    rescue_personel_id: Optional[int]
    rescuer_id: List[int]

    def to_dict(self):
        return {
            "Rescue Personel ID": self.rescue_personel_id,
            "Rescuer ID": self.rescuer_id,
        }

    class Config:
        from_attributes = True

class Rescue_Personel_SchemaBaseResponse(BaseModel):
    status_code: int
    data: Optional[Rescue_Personel_SchemaBase] = None

class Rescue_Personel_SchemaBaseListResponse(BaseModel):
    status_code: int
    data: List[Rescue_Personel_SchemaBase] = []