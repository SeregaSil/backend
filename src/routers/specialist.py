from datetime import date
from typing import List
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse
from src.core.period import create_time_range
from src.database import get_connector
from src.schemas.specialist import SpecialistInfo, SpecialistPeriod, SpeciallistReport
from src.schemas.check import CheckBase
from src.schemas.service import ServiceBase
from src.schemas.report import ReportDate
from src.core.auth import get_current_connector, User
from psycopg2.errors import InsufficientPrivilege
router = APIRouter(tags=['Specialists'], prefix='/specialists')

@router.get('', response_model=List[SpecialistInfo])
def get_specialists(user: User = Depends(get_current_connector)):
    if user.role != 'Менеджер':
        raise InsufficientPrivilege
    with user.conn as conn:
        with conn.cursor() as cur:
            cur.execute('''SELECT employee_id, full_name, rating, post
                                FROM employees
                            WHERE employees.post IN ('Парикмахер') 
                            GROUP BY employee_id;''')
            employees: List[SpecialistInfo] = cur.fetchall()
            return employees
        
@router.post('/{specialist_id}/period', response_model=List[SpecialistPeriod])
def get_period_for_specialist(specialist_id: int, check: CheckBase, user: User = Depends(get_current_connector)):
    if user.role != 'Менеджер':
        raise InsufficientPrivilege
    with user.conn as conn:
        with conn.cursor() as cur:
            return create_time_range(cur, specialist_id, check.establishment_id, check.services_id)
        
@router.get('/{specialist_id}/services', response_model=List[ServiceBase])
def get_all_services_by_specialist(specialist_id: int, user: User = Depends(get_current_connector)):
    if user.role not in ['Управляющий', 'Аналитик', 'Менеджер']:
        raise InsufficientPrivilege
    with user.conn as conn:
        with conn.cursor() as cur:
            cur.execute('''SELECT service_id, name_service, cost, (duration / 60) as duration 
                                FROM services
                                INNER JOIN employee_service USING(service_id)
                            WHERE employee_id = %s;''', (specialist_id,))
            res: List[ServiceBase] = cur.fetchall()
            return res
        
@router.post('/report', response_model=List[SpeciallistReport])
def get_all_specialists_report(report_date: ReportDate, user: User = Depends(get_current_connector)):
    if user.role !='Аналитик':
        raise InsufficientPrivilege
    with user.conn as conn:
        with conn.cursor() as cur:
            cur.execute('SELECT * FROM employees_profit_for_period(%s, %s);',(report_date.start_date, report_date.end_date,))
            res: List[SpeciallistReport] = cur.fetchall()
            return res
        
@router.get('/report/download')
def get_specialists_report_csv(start_date: date, end_date: date, user: User = Depends(get_current_connector)):
    if user.role !='Аналитик':
        raise InsufficientPrivilege
    with user.conn as conn:
        with conn.cursor() as cur:
            cur.execute('''COPY (SELECT full_name as ФИО, profit as Полученная_прибыль, period_grade as Средняя_оценка, amount_checks as Количество_заказов
                                FROM employees_profit_for_period(%s, %s)) TO '/tmp/specialists_report.csv' 
                            DELIMITER ',' CSV HEADER;''', (start_date, end_date,))
            return FileResponse('reports/specialists_report.csv', media_type='text/csv', 
                                filename=f'Отчёт_по_работникам({start_date}_{end_date}).csv',
                                headers={"Access-Control-Expose-Headers": "Content-Disposition"})      