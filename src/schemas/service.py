from pydantic import BaseModel
from datetime import timedelta

class ServiceBase(BaseModel):
    service_id: int
    name_service: str
    cost: int
    duration: timedelta
    
class ServiceReport(BaseModel):
    service_id: int 
    name_service: str 
    profit: int
    amount_checks: int