from pydantic import BaseModel
from datetime import date

class ReportDate(BaseModel):
    start_date: date
    end_date: date