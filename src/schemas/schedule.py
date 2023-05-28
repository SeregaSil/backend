from datetime import date, time
import re
from pydantic import BaseModel, validator, root_validator


class ScheduleUpdate(BaseModel):
    date_work: date
    start_work: time
    end_work: time 
    presence: bool
    
    @root_validator
    def parse_times(cls, values):
        if values.get('end_work') <= values.get('start_work'):
            raise ValueError("Times Invalid")
        return values
    
class ScheduleCreate(ScheduleUpdate):
    presence: bool | None = True
    telephone: str
    
    @validator('telephone')
    def parse_telephone(cls, value):
      regex = r'(\+7) (\(9(\d{2})\)) (\d{3})-(\d{2})-(\d{2})'
      if value and not re.match(regex, value):
          raise ValueError("Phone Number Invalid")
      return value