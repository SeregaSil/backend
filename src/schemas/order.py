from datetime import date, time, timedelta
from typing import List
from pydantic import BaseModel, validator

class OrderInfo(BaseModel):
    service_id: int
    start_order: time
    end_order: time
    name_service: str
    cost: int
    
    @validator('start_order', pre=False)
    def parse_start_order(cls, value):
        return value.strftime('%H:%M')
    
    @validator('end_order', pre=False)
    def parse_end_order(cls, value):
        return value.strftime('%H:%M')  