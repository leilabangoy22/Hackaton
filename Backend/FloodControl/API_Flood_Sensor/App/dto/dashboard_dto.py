from pydantic import BaseModel
from typing import Optional

class request_statusBase(BaseModel):
    pending : int
    assigned : int
    completed : int
    
    def to_dict(self):
        return{
            "Pending" : self.pending,
            "Assigned" : self.assigned,
            "Completed" : self.completed
        }
    
    class Config:
        from_attributes = True

class request_statusBaseResponse(BaseModel):
    status_code : int
    data : Optional[request_statusBase] = None