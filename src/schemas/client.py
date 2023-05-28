from datetime import time, date
import re
from pydantic import BaseModel, EmailStr, validator


class ClientCreate(BaseModel):
    full_name: str
    telephone: str
    email: EmailStr | None
    
    @validator('telephone')
    def parse_telephone(cls, value):
      regex = r'(\+7) (\(9(\d{2})\)) (\d{3})-(\d{2})-(\d{2})'
      if value and not re.match(regex, value):
          raise ValueError("Phone Number Invalid.")
      return value
    
class ClientInfo(ClientCreate):
    client_id: int
    email: EmailStr | None
    amount_visits: int 
    bonus: int 
    estate: str


class ClientUpdate(ClientCreate):
    pass
    
