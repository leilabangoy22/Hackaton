from pydantic import BaseModel

class StatusResponseBase(BaseModel):
    status_code: int
    data: bool