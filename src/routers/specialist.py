from typing import List
from fastapi import APIRouter, Depends, HTTPException

from src.core.period import create_time_range
from src.database import get_connector
from src.schemas.specialist import SpecialistInfo, SpecialistPeriod, SpeciallistReport
from src.schemas.check import CheckBase
from src.schemas.service import ServiceBase
from src.schemas.report import ReportDate
from src.core.auth import get_current_connector
from psycopg2._psycopg import connection
router = APIRouter(tags=['Specialists'], prefix='/specialists')

@router.get('', response_model=List[SpecialistInfo])
def get_specialists(conn: connection = Depends(get_current_connector)):
    with conn:
        with conn.cursor() as cur:
            cur.execute('''SELECT employee_id, full_name, rating, post
                                FROM employees
                            WHERE employees.post IN ('Парикмахер') 
                            GROUP BY employee_id;''')
            employees: List[SpecialistInfo] = cur.fetchall()
            return employees
        
@router.post('/{specialist_id}/period', response_model=List[SpecialistPeriod])
def get_period_for_specialist(specialist_id: int, check: CheckBase, conn: connection = Depends(get_current_connector)):
    with conn:
        with conn.cursor() as cur:
            return create_time_range(cur, specialist_id, check.establishment_id, check.services_id)
        
@router.get('/{specialist_id}/services', response_model=List[ServiceBase])
def get_all_services_by_specialist(specialist_id: int, conn: connection = Depends(get_current_connector)):
    with conn:
        with conn.cursor() as cur:
            cur.execute('''SELECT service_id, name_service, cost, (duration / 60) as duration 
                                FROM services
                                INNER JOIN employee_service USING(service_id)
                            WHERE employee_id = %s;''', (specialist_id,))
            res: List[ServiceBase] = cur.fetchall()
            return res
        
@router.post('/report', response_model=List[SpeciallistReport])
def get_all_specialists_report(report_date: ReportDate, conn: connection = Depends(get_current_connector)):
    with conn:
        with conn.cursor() as cur:
            cur.execute('SELECT * FROM employees_profit_for_period(%s, %s);',(report_date.start_date, report_date.end_date,))
            res: List[SpeciallistReport] = cur.fetchall()
            return res
        
@router.post('/{specialist_id}/report', response_model=SpeciallistReport)
def get_specialist_report(specialist_id: int, report_date: ReportDate, conn: connection = Depends(get_current_connector)):
    with conn:
        with conn.cursor() as cur:
            cur.execute('SELECT * FROM employees_profit_for_period(%s, %s) WHERE employee_id = %s;',(report_date.start_date, report_date.end_date, specialist_id,))
            specialist: SpeciallistReport = cur.fetchone()
            if not specialist:
                raise HTTPException(status_code=404, detail='Not Found')
            return specialist