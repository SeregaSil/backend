from typing import List
from fastapi import APIRouter, Depends, HTTPException
from src.database import get_connector

from src.schemas.specialist import SpecialistInfo
from src.schemas.establishment import EstablishmentBase, EstablishmentReport
from src.schemas.report import ReportDate

from src.core.auth import get_current_connector
from psycopg2._psycopg import connection

router = APIRouter(tags=['Establishments'], prefix='/establishments')

@router.get('', response_model=List[EstablishmentBase])
def get_all_establishments(conn: connection = Depends(get_current_connector)):
    with conn:
        with conn.cursor() as cur:
            cur.execute('SELECT * FROM establishments;')
            res: List[EstablishmentBase] = cur.fetchall()
            return res
        
@router.get('/{establishment_id}/specialists', response_model=List[SpecialistInfo])
def get_specialists_for_establishment(establishment_id: int, conn: connection = Depends(get_current_connector)):
    with conn:
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
def get_all_establishments_report(report_date: ReportDate, conn: connection = Depends(get_current_connector)):
    with conn:
        with conn.cursor() as cur:
            cur.execute('SELECT * FROM establishments_profit_for_period(%s, %s);',(report_date.start_date, report_date.end_date,))
            res: List[EstablishmentReport] = cur.fetchall()
            return res

# @router.post('/{establishment_id}/report', response_model=EstablishmentReport)
# def get_establishment_report(establishment_id: int, report_date: ReportDate):
#     with get_connector() as con:
#         with con.cursor() as cur:
#             cur.execute('SELECT * FROM establishments_profit_for_period(%s, %s) WHERE establishment_id = %s;',(report_date.start_date, report_date.end_date, establishment_id,))
#             establishment: EstablishmentReport = cur.fetchone()
#             if not establishment:
#                 raise HTTPException(status_code=404, detail='Not Found')
#             return establishment