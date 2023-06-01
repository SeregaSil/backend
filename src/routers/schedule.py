from typing import Annotated, List
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from src.database import get_connector
from src.core.auth import get_current_connector, User
from psycopg2.errors import InsufficientPrivilege 
from src.schemas.schedule import ScheduleUpdate, ScheduleCreate
router = APIRouter(tags=['Schedules'], prefix='/schedules')

@router.delete('/{schedule_id}')
def delete_schedule(schedule_id: int, user: User = Depends(get_current_connector)):
    if user.role !='Управляющий':
        raise InsufficientPrivilege    
    with user.conn as conn:
        with conn.cursor() as cur:
            cur.execute('''DELETE FROM schedule WHERE schedule_id = %s;''', (schedule_id,))

@router.patch('/{schedule_id}')
def update_schedule(schedule_id: int, new_schedule: ScheduleUpdate, user: User = Depends(get_current_connector)):
    if user.role !='Управляющий':
        raise InsufficientPrivilege  
    with user.conn as conn:
        with conn.cursor() as cur:
            cur.execute('''SELECT date_work
                            FROM schedule
                            WHERE schedule_id = %s''', (schedule_id,))
            old_date_work = cur.fetchone().get('date_work')
            cur.execute('''SELECT ARRAY (
                                SELECT date_work 
                                FROM schedule
                                WHERE employee_id = (
                                    SELECT employee_id 
                                    FROM schedule 
                                    WHERE schedule_id = %s)
                                ) as dates''', (schedule_id,))
            dates = cur.fetchone().get('dates')
            if new_schedule.date_work in dates and old_date_work != new_schedule.date_work:
                raise HTTPException(status_code=409, detail='Неприемлемые данные')
            cur.execute('''UPDATE schedule
                            SET date_work = %s,
                            start_work = %s,
                            end_work = %s,
                            presence = %s
                            WHERE schedule_id = %s''', 
                            (new_schedule.date_work, new_schedule.start_work, new_schedule.end_work, new_schedule.presence, schedule_id,))


@router.post('')
def create_schedule(new_schedule: ScheduleCreate, user: User = Depends(get_current_connector)):
    if user.role !='Управляющий':
        raise InsufficientPrivilege  
    with user.conn as conn:
        with conn.cursor() as cur:
            cur.execute('''SELECT establishment_id FROM establishments;''')
            establishment_id = cur.fetchone().get('establishment_id')
            cur.execute('''SELECT employee_id FROM employees WHERE telephone = %s;''', (new_schedule.telephone,))
            employee_id = cur.fetchone().get('employee_id')
            if not employee_id:
                raise HTTPException(status_code=404, detail='Not Found')
            cur.execute('''SELECT date_work FROM schedule 
                            WHERE employee_id = %s AND date_work = %s''', (employee_id, new_schedule.date_work,))
            if cur.fetchone():
                raise HTTPException(status_code=409, detail='Неприемлемые данные')
            cur.execute('''INSERT INTO schedule (date_work, start_work, end_work, establishment_id, employee_id)
                            VALUES (%s, %s, %s, %s, %s)''',
                            (new_schedule.date_work, new_schedule.start_work, new_schedule.end_work, establishment_id, employee_id,))
                        