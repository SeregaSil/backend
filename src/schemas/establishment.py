from pydantic import BaseModel

class EstablishmentBase(BaseModel):
    establishment_id: int
    address_establishment: str
    postcode: int
    telephone: str
    amount_employees: int
    
class EstablishmentReport(BaseModel):
    establishment_id: int
    address_establishment: str
    profit: int
    amount_checks: int