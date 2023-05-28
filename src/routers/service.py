from typing import List
from fastapi import APIRouter, Depends, HTTPException
from psycopg2._psycopg import connection
from src.database import get_connector
from src.core.auth import get_current_connector
from psycopg2._psycopg import connection
from src.schemas.service import ServiceBase, ServiceReport
from src.schemas.report import ReportDate
from src.core.auth import get_current_connector

router = APIRouter(tags=['Services'], prefix='/services')

@router.get('', response_model=List[ServiceBase])
def get_all_services(conn: connection = Depends(get_connector)):
    with conn:
        with conn.cursor() as cur:
            cur.execute('SELECT service_id, name_service, cost, (duration / 60) as duration FROM public.services;')
            res: List[ServiceBase] = cur.fetchall()
            return res
        
@router.post('/report', response_model=List[ServiceReport])
def get_all_services_report(report_date: ReportDate, conn: connection = Depends(get_current_connector)):
    with conn:
        with conn.cursor() as cur:
            cur.execute('SELECT * FROM public.services_profit_for_period(%s, %s);',(report_date.start_date, report_date.end_date,))
            res: List[ServiceReport] = cur.fetchall()
            return res
        
@router.post('/{service_id}/report', response_model=ServiceReport)
def get_service_report(service_id: int, report_date: ReportDate, conn: connection = Depends(get_current_connector)):
    with conn:
        with conn.cursor() as cur:
            cur.execute('SELECT * FROM services_profit_for_period(%s, %s) WHERE service_id = %s;',(report_date.start_date, report_date.end_date, service_id,))
            service: ServiceReport = cur.fetchone()
            if not service:
                raise HTTPException(status_code=404, detail='Not Found')
            return service