from datetime import date, time
from typing import List
from pydantic import BaseModel, validator

class CheckPaid(BaseModel):
    grade: float | None = None
    paid_bonus: int = 0

class CheckBase(BaseModel):
    establishment_id: int
    services_id: List[int]
    
class CheckCreate(CheckBase):
    employee_id: int
    client_id: int  
    date: date
    time: time

class CheckInfo(BaseModel):
    check_id: int
    date_check: date
    total_cost: int
    start_time: time
    end_time: time
    paid: bool
    full_name: str
    address_establishment: str
    post: str
    client_id: int
    
    @validator('start_time', pre=False)
    def parse_start_time(cls, value):
        return value.strftime('%H:%M')
    
    @validator('end_time', pre=False)
    def parse_end_time(cls, value):
        return value.strftime('%H:%M')