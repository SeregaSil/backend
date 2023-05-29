import re
from typing import List
from pydantic import BaseModel, EmailStr, validator, root_validator
from datetime import date, time
from .specialist import SpecialistInfo

class EmployeeGetSchedule(BaseModel):
    schedule_id: int
    date_work: date 
    start_work: time 
    end_work: time
    full_name: str
    post: str
    presence: bool
    address_establishment: str
    
    @validator('start_work', pre=False)
    def parse_start_work(cls, value):
        return value.strftime('%H:%M')
    
    @validator('end_work', pre=False)
    def parse_end_work(cls, value):
        return value.strftime('%H:%M')

class EmployeeInfo(SpecialistInfo):
    email: EmailStr | None
    experience: int
    salary: int
    brief_info: str | None
    age: int
    services_id: List[int] | None
    telephone: str

class EmployeeUpdate(BaseModel):
    email: EmailStr | None
    experience: int
    salary: int
    brief_info: str | None
    age: int
    services_id: List[int] | None = None
    full_name: str
    telephone: str
    
    @validator('telephone')
    def parse_telephone(cls, value):
      regex = r'(\+7) (\(9(\d{2})\)) (\d{3})-(\d{2})-(\d{2})'
      if value and not re.match(regex, value):
          raise ValueError("Phone Number Invalid.")
      return value

class EmployeeCreate(EmployeeUpdate):
    post: str
    
class EmployeeRegister(BaseModel):
    password: str
    
    
class EmployeeLoginData(BaseModel):
    employee_id: int
    full_name: str
    telephone: str
    post: str
    login: str | None