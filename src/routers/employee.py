from datetime import date
from typing import Annotated, List
from fastapi import APIRouter, Depends, HTTPException, Query
from src.database import get_connector

from src.schemas.employee import EmployeeGetSchedule, EmployeeInfo, EmployeeUpdate, EmployeeCreate, EmployeeRegister
from src.core.auth import get_current_connector
from psycopg2._psycopg import connection

router = APIRouter(tags=['Employees'], prefix='/employees')


@router.get('/info', response_model=EmployeeInfo)
def get_employee_by_telephone(
    telephone: Annotated[
        str, Query(min_length=18, max_length=18,
                    regex='(\+7) (\(9(\d{2})\)) (\d{3})-(\d{2})-(\d{2})')
    ], conn: connection = Depends(get_current_connector)
):
    with conn:
        with conn.cursor() as cur:
            cur.execute('''SELECT employee_id, full_name, telephone, 
                                email, experience, salary, brief_info, 
                                age, post, rating, 
                                CASE
                                WHEN post IN('Парикмахер') THEN ARRAY (
                                    SELECT service_id
                                    FROM employee_service
                                    WHERE employee_id = empl.employee_id
                                )
                                ELSE NULL
                                END AS services_id
                                FROM employees empl
                                LEFT JOIN employee_service USING(employee_id)
                                WHERE telephone = %s
                            GROUP BY employee_id;''', (telephone,))
            empl: EmployeeInfo = cur.fetchone()
            if not empl:
                raise HTTPException(status_code=404, detail='Not Found')
            return empl


@router.get('/schedules', response_model=List[EmployeeGetSchedule])
def get_employee_schedule(
    telephone: Annotated[
        str | None, Query(min_length=18, max_length=18,
                          regex='(\+7) (\(9(\d{2})\)) (\d{3})-(\d{2})-(\d{2})')
    ] = None,
    date_work: date | None = None,
    presence: bool | None = None, 
    conn: connection = Depends(get_current_connector)
):
    with conn:
        with conn.cursor() as cur:
            cur.execute('''SELECT * FROM get_employee_schedule(%s, %s, %s)''',
                        (telephone, date_work, presence,))
            res: List[EmployeeGetSchedule] = cur.fetchall()
            return res


@router.get('', response_model=List[EmployeeInfo])
def get_all_employees(conn: connection = Depends(get_current_connector)):
    with conn:
        with conn.cursor() as cur:
            cur.execute(''' SELECT employee_id, full_name, telephone, 
                                email, experience, salary, brief_info, 
                                age, post, rating, 
                                CASE
                                WHEN post IN('Парикмахер') THEN ARRAY (
                                    SELECT service_id
                                    FROM employee_service
                                    WHERE employee_id = empl.employee_id
                                )
                                ELSE NULL
                                END AS services_id
                                FROM employees empl
                                LEFT JOIN employee_service USING(employee_id)
                            GROUP BY employee_id;''')
            res: List[EmployeeInfo] = cur.fetchall()
            return res


@router.get('/{employee_id}', response_model=EmployeeInfo)
def get_employee(employee_id: int, conn: connection = Depends(get_current_connector)):
    with conn:
        with conn.cursor() as cur:
            cur.execute('''SELECT employee_id, full_name, telephone, 
                                email, experience, salary, brief_info, 
                                age, post, rating, 
                                CASE
                                WHEN post IN('Парикмахер') THEN ARRAY (
                                    SELECT service_id
                                    FROM employee_service
                                    WHERE employee_id = empl.employee_id
                                )
                                ELSE NULL
                                END AS services_id
                                FROM employees empl
                                LEFT JOIN employee_service USING(employee_id)
                                WHERE employee_id = %s
                            GROUP BY employee_id;''', (employee_id,))
            empl: EmployeeInfo = cur.fetchone()
            if not empl:
                raise HTTPException(status_code=404, detail='Not Found')
            return empl


@router.delete('/{employee_id}')
def delete_employee(employee_id: int, conn: connection = Depends(get_current_connector)):
    with conn:
        with conn.cursor() as cur:
            cur.execute(
                '''DELETE FROM employees WHERE employee_id = %s''', (employee_id,))


@router.put('/{employee_id}')
def update_employee(employee_id: int, new_employee: EmployeeUpdate, conn: connection = Depends(get_current_connector)):
    with conn:
        with conn.cursor() as cur:
            cur.execute('''UPDATE employees
                            SET telephone = %s, email = %s, experience = %s,
                            salary = %s, brief_info = %s, age = %s, post = %s
                            WHERE employee_id = %s''',
                        (new_employee.telephone, new_employee.email, new_employee.experience,
                         new_employee.salary, new_employee.brief_info, new_employee.age,
                         new_employee.post, employee_id,))
            if new_employee.services_id:
                cur.execute('''DELETE FROM employee_service
                                WHERE employee_id = %s''', (employee_id,))
                for ser_id in new_employee.services_id:
                    cur.execute('''INSERT INTO employee_service(employee_id, service_id)
                                    VALUES(%s, %s)''', (employee_id, ser_id,))


@router.post('')
def create_employee(new_employee: EmployeeCreate, conn: connection = Depends(get_current_connector)):
    with conn:
        with conn.cursor() as cur:
            cur.execute('''INSERT INTO employees(full_name, telephone, email, 
                                experience, salary, brief_info, age, post)
                            VALUES(%s, %s, %s, %s, %s, %s, %s, %s)
                            RETURNING employee_id''',
                        (new_employee.full_name, new_employee.telephone, new_employee.email, new_employee.experience,
                         new_employee.salary, new_employee.brief_info, new_employee.age, new_employee.post))
            if new_employee.services_id:
                employee_id: int = cur.fetchone().get('employee_id')
                for ser_id in new_employee.services_id:
                    cur.execute('''INSERT INTO employee_service(employee_id, service_id)
                                    VALUES(%s, %s)''', (employee_id, ser_id,))

@router.post('/{employee_id}/account')
def register_employee(employee_id: int, employee_user: EmployeeRegister, conn: connection = Depends(get_current_connector)):
    with conn:
        with conn.cursor() as cur:
            cur.execute('''INSERT INTO users(hash_password, employee_id)
                            VALUES(%s, %s)
                            RETURNING login''', (employee_user.password, employee_id,))
            login = cur.fetchone()
            return login

@router.patch('/{employee_id}/account')
def register_employee(employee_id: int, employee_user: EmployeeRegister, conn: connection = Depends(get_current_connector)):
    with conn:
        with conn.cursor() as cur:
            cur.execute('''UPDATE users
                            SET hash_password = %s
                            WHERE employee_id = %s
                            RETURNING login''', (employee_user.password, employee_id,))
            login = cur.fetchone()
            return login


@router.delete('/{employee_id}/account')
def register_employee(employee_id: int, conn: connection = Depends(get_current_connector)):
    with conn:
        with conn.cursor() as cur:
            cur.execute('''DELETE FROM users
                            WHERE employee_id = %s''', (employee_id,))
