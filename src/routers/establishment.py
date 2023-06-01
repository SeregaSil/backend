import csv
from datetime import date
from typing import List
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse
from src.database import get_connector

from src.schemas.specialist import SpecialistInfo
from src.schemas.establishment import EstablishmentBase, EstablishmentReport
from src.schemas.report import ReportDate

from src.core.auth import get_current_connector, User
from psycopg2.errors import InsufficientPrivilege

router = APIRouter(tags=['Establishments'], prefix='/establishments')

@router.get('', response_model=List[EstablishmentBase])
def get_all_establishments(user: User = Depends(get_current_connector)):
    if user.role not in ['Управляющий', 'Аналитик', 'Менеджер']:
        raise InsufficientPrivilege
    with user.conn as conn:
        with conn.cursor() as cur:
            cur.execute('SELECT * FROM establishments;')
            res: List[EstablishmentBase] = cur.fetchall()
            return res
        
@router.get('/{establishment_id}/specialists', response_model=List[SpecialistInfo])
def get_specialists_for_establishment(establishment_id: int, user: User = Depends(get_current_connector)):
    if user.role not in ['Управляющий', 'Аналитик', 'Менеджер']:
        raise InsufficientPrivilege
    with user.conn as conn:
        with conn.cursor() as cur:
            cur.execute('''SELECT employee_id, full_name, rating, post
                                FROM employees
                                INNER JOIN schedule USING(employee_id)
                            WHERE employees.post IN ('Парикмахер') 
                                AND establishment_id = %s
                                AND presence is True
                            GROUP BY employee_id;''', (establishment_id, ))
            employees: List[SpecialistInfo] = cur.fetchall()
            return employees

@router.post('/report', response_model=List[EstablishmentReport])
def get_all_establishments_report(report_date: ReportDate, user: User = Depends(get_current_connector)):
    if user.role !='Аналитик':
        raise InsufficientPrivilege
    with user.conn as conn:
        with conn.cursor() as cur:
            cur.execute('SELECT * FROM establishments_profit_for_period(%s, %s);',(report_date.start_date, report_date.end_date,))
            res: List[EstablishmentReport] = cur.fetchall()
            return res

@router.get('/report/download')
def get_all_establishments_report_csv(start_date: date, end_date: date, user: User = Depends(get_current_connector)):
    if user.role !='Аналитик':
        raise InsufficientPrivilege    
    with user.conn as conn:
        with conn.cursor() as cur:
            cur.execute('''COPY (
                SELECT address_establishment as Адрес_заведения, 
                    profit as Полученная_прибыль, 
                    amount_checks as Количество_посещений
                FROM establishments_profit_for_period(%s, %s)) TO '/tmp/establishments_report.csv' 
                DELIMITER ',' CSV HEADER;''', (start_date, end_date,))
            return FileResponse('reports/establishments_report.csv', 
                                media_type='text/csv', 
                                filename=f'Отчёт_по_заведениям({start_date}_{end_date}).csv',
                                headers={"Access-Control-Expose-Headers": "Content-Disposition"})
