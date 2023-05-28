import re
from typing import List
from pydantic import BaseModel, validator, EmailStr
from datetime import date, datetime

class SpecialistBase(BaseModel):
    employee_id: int
    full_name: str

 
class SpecialistInfo(SpecialistBase):
    rating: float | None
    post: str


class SpecialistPeriod(BaseModel):
    date: date
    times: List[datetime]
    
    @validator('times', pre=False)
    def parse_time(cls, value):
        return [x.strftime('%H:%M') for x in value] 

    
class SpeciallistReport(SpecialistBase):
    profit: int
    period_grade: float
    amount_checks: int