
from datetime import date
from typing import List
from fastapi import APIRouter, Depends, HTTPException
from src.database import get_connector

from src.schemas.check import CheckCreate, CheckInfo, CheckPaid
from src.schemas.order import OrderInfo

from src.core.auth import get_current_connector
from psycopg2._psycopg import connection

router = APIRouter(tags=['Checks'], prefix='/checks')


@router.delete('/{check_id}')
def delete_check(check_id: int, conn: connection = Depends(get_current_connector)):
    with conn:
        with conn.cursor() as cur:
            cur.execute('''DELETE FROM checks WHERE check_id = %s''', (check_id, ))
            
@router.get('/{check_id}', response_model=List[OrderInfo])
def get_check_info(check_id: int, conn: connection = Depends(get_current_connector)):
    with conn:
        with conn.cursor() as cur:
            cur.execute('''SELECT service_id, start_order, end_order, name_service, cost
                            FROM orders
                                INNER JOIN services USING(service_id)
                            WHERE check_id = %s''', (check_id,))
            orders: List[OrderInfo] = cur.fetchall()
            return orders

@router.patch('/{check_id}')
def pay_and_mark_check(check_id: int, check: CheckPaid, conn: connection = Depends(get_current_connector)):
    with conn:
        with conn.cursor() as cur:
            cur.execute('''UPDATE checks
                            SET grade = %s, 
                                paid = %s,
                                total_cost = total_cost - %s
                            WHERE check_id = %s
                            RETURNING client_id''', (check.grade, True, check.paid_bonus, check_id,))
            client_id: int = cur.fetchone().get('client_id')
            cur.execute('''UPDATE clients
                            SET bonus = bonus - %s
                            WHERE client_id = %s''', (check.paid_bonus, client_id))

@router.post('')
def create_check(order: CheckCreate, conn: connection = Depends(get_current_connector)):
    with conn:
        with conn.cursor() as cur:
            cur.execute('''CALL insert_check(%s, %s, %s, %s, %s);''',
                        (order.date, order.client_id, order.services_id, order.employee_id, order.time,))

            
@router.get('/clients/{client_id}', response_model=List[CheckInfo])
def get_all_checks_for_client(client_id: int, check_date: date | None = None, paid: bool | None = None, conn: connection = Depends(get_current_connector)):
    with conn:
        with conn.cursor() as cur:
            cur.execute('''SELECT * FROM get_all_checks(%s, %s) WHERE client_id = %s''', (check_date, paid, client_id,))
            checks: List[CheckInfo] = cur.fetchall()
            return checks


@router.get('', response_model=List[CheckInfo])
def get_all_checks(check_date: date | None = None, paid: bool | None = None, conn: connection = Depends(get_current_connector)):
    with conn:
        with conn.cursor() as cur:
            cur.execute('''SELECT * FROM get_all_checks(%s, %s);''', (check_date, paid,))
            checks: List[CheckInfo] = cur.fetchall()
            return checks