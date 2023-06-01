from datetime import date
from typing import List
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse
from psycopg2._psycopg import connection
from src.database import get_connector
from src.core.auth import get_current_connector, User
from psycopg2._psycopg import connection
from psycopg2.errors import InsufficientPrivilege
from src.schemas.service import ServiceBase, ServiceReport
from src.schemas.report import ReportDate
from src.core.auth import get_current_connector

router = APIRouter(tags=['Services'], prefix='/services')

@router.get('', response_model=List[ServiceBase])
def get_all_services(con: connection = Depends(get_connector)):
    with con:
        with con.cursor() as cur:
            cur.execute('SELECT service_id, name_service, cost, (duration / 60) as duration FROM public.services;')
            res: List[ServiceBase] = cur.fetchall()
            return res
        
@router.post('/report', response_model=List[ServiceReport])
def get_all_services_report(report_date: ReportDate, user: User = Depends(get_current_connector)):
    if user.role !='Аналитик':
        raise InsufficientPrivilege
    with user.conn as conn:
        with conn.cursor() as cur:
            cur.execute('SELECT * FROM public.services_profit_for_period(%s, %s);',(report_date.start_date, report_date.end_date,))
            res: List[ServiceReport] = cur.fetchall()
            return res
        
@router.get('/report/download')
def get_service_report_csv(start_date: date, end_date: date, user: User = Depends(get_current_connector)):
    if user.role !='Аналитик':
        raise InsufficientPrivilege
    with user.conn as conn:
        with conn.cursor() as cur:
            cur.execute('''COPY (SELECT name_service as Наименование_услуги, profit as Полученная_прибыль, amount_checks as Количество_заказов
                                FROM services_profit_for_period(%s, %s)) TO '/tmp/services_report.csv' 
                            DELIMITER ',' CSV HEADER;''', (start_date, end_date,))
            return FileResponse('reports/services_report.csv', media_type='text/csv', 
                                filename=f'Отчёт_по_услугам({start_date}_{end_date}).csv',
                                headers={"Access-Control-Expose-Headers": "Content-Disposition"}) 