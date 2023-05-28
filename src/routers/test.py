import csv
from datetime import date, datetime, time, timedelta
from typing import Dict, List
from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import FileResponse, StreamingResponse
from io import StringIO, BytesIO

from src.database import get_connector
from src.schemas.specialist import SpecialistPeriod

router = APIRouter(tags=['Test'])
# SELECT employee_id, order_id, start_order, end_order
# FROM order_employee
# 	 INNER JOIN orders USING(order_id)
	 
# WHERE order_employee.employee_id = 15
# ORDER BY employee_id

# def create_range_string(breaks, cur):
#     with cur:
#         date = breaks[0].get('date_check')
#         cur.execute('''SELECT start_work, end_work
#                         FROM employees
#                             INNER JOIN schedule USING(employee_id)
#                         WHERE employees.position IN ('Парикмахер')
#                         AND date_work = %s
#                         ORDER BY employee_id''', (date,))
#         res = cur.fetchone()
#         start = res.get('start_work').strftime('%H:%M')
#         end = res.get('end_work').strftime('%H:%M')
#     dates = list(pandas.date_range(start=start, end=end, freq="0.5H").strftime('%H:%M'))
#     for i in range(len(breaks)):
#         break_start = breaks[i].get('start_time').strftime('%H:%M')
#         break_end = breaks[i].get('end_time').strftime('%H:%M')
#         dates = [x for x in dates if int(x.split(":")[0]) < break_start or int(x.split(":")[0]) >= break_end]
#     return dates

def work_create_time_range(cur, employee_id):
    cur.execute('''SELECT date_work, start_work, end_work
                        FROM employees
                            INNER JOIN schedule USING(employee_id)
                        WHERE employees.post IN ('Парикмахер') 
                        AND employee_id = %s''', (employee_id,))
    employee_schedule = cur.fetchall()
    
    cur.execute('''SELECT date_check, MIN(start_order) as start_time, MAX(end_order) as end_time
                    FROM orders
                    INNER JOIN checks USING(check_id)
                        INNER JOIN order_employee USING(order_id)
                    WHERE employee_id = %s
                    GROUP BY checks.check_id''', (employee_id,))
    
    orders_intervals = cur.fetchall()
    schedule = []
    for i in range(len(employee_schedule)):
            breaks = [x for x in orders_intervals if x.get('date_check') == employee_schedule[i].get('date_work')]
        # for j in range(len(orders_intervals)):
            times = []
            # if employee_schedule[i].get('date_work') == orders_intervals[j].get('date_check'):
            start = datetime.combine(date.today(), employee_schedule[i].get('start_work'))
            end = datetime.combine(date.today(), employee_schedule[i].get('end_work'))
            while start <= end:
                times.append(datetime.time(start))
                start += timedelta(minutes=15)
            schedule.append(SpecialistPeriod(date=employee_schedule[i].get('date_work'), date_correct=employee_schedule[i].get('date_work'), times=work_clear_interval(breaks, times)))
            # schedule.update({employee_schedule[i].get('date_work'): clear_interval(breaks, times)})
    return schedule

def work_clear_interval(breaks, times: List[time]):
    res = []
    if breaks == []:
        return times
    else:
        for j in range(len(breaks)):
            start = breaks[j].get('start_time')
            end = breaks[j].get('end_time')
            for t in times:
                if t < start or t > end:
                    res.append(t)
            times = res.copy()
            res.clear()
        return times
        
    
@router.get('/test/{employee_id}')
def test_test(employee_id: int):
    with get_connector() as con:
        with con.cursor() as cur:
            return work_create_time_range(cur, employee_id)
            # cur.execute('''SELECT date_check, MIN(start_order) as start_time, MAX(end_order) as end_time
            #                 FROM orders
            #                     INNER JOIN checks USING(check_id)honkai star rail
            #                     INNER JOIN order_employee USING(order_id)
            #                 WHERE employee_id = %s
            #                 GROUP BY checks.check_id''', (employee_id,))
            # res = cur.fetchall()[0].get('date_check')
            # cur.execute('''SELECT start_work, end_work
            #             FROM employees
            #                 INNER JOIN schedule USING(employee_id)
            #             WHERE employees.position IN ('Парикмахер')
            #             AND date_work = %s
            #             ORDER BY employee_id''', (res,))
            # res = cur.fetchall()[0]
            # return (create_time_range(
            #     res.get('start_work'),
            #     res.get('end_work')
            # ))


            # call insert_check('2023-04-21', 2, '{2, 3, 4}', 14, '17:30:00')
            # cur.execute('''INSERT INTO checks(date_check, client_id)
            #                 VALUES(%s, %s)
            #                 RETURNING check_id''', (order.date, order.client_id,))
            # check_id = cur.fetchone().get('check_id')
            
            # for service_id in order.services_id:
            #     cur.execute('''INSERT INTO orders(start_order, check_id)
            #                     VALUES(%s, %s)
            #                     RETURNING order_id''', (order.time, check_id,))
            #     order_id = cur.fetchone().get('order_id')
                
            #     cur.execute('''INSERT INTO order_service(order_id, service_id)
            #                     VALUES(%s, %s)''', (order_id, service_id,))
                
            #     cur.execute('''INSERT INTO order_employee(order_id, employee_id)
            #                     VALUES(%s, %s)''', (order_id, order.employee_id,))
            #     if order.time != default_start_time:
            #         order.time = default_start_time
            
@router.get("/a")
async def session_set(request: Request):
    request.session["my_var"] = "1234"
    return 'ok'


@router.get("/b")
async def session_info(request: Request):
    my_var = request.session.get("my_var", None)
    return my_var

@router.get('/1')
def bbbb():
    with get_connector() as con:
        with con.cursor() as cur:
            cur.execute('SELECT * FROM establishments_profit_for_period(%s, %s);', ('2021-01-01', '2025-01-01',))
            column_names = []
            for row in cur.description:
                column_names.append(row[0])
            
            file = StringIO()
                
            write_filename = csv.DictWriter(file, fieldnames=column_names, delimiter=' ')
            write_filename.writeheader()
            write_filename.writerows(cur)
            file.seek(0)
            return StreamingResponse(file, media_type="text/csv", headers={'Content-Disposition': 'filename=generated.csv'})
        
@router.get('/lll')
def lll(username: str, password: str):
    with get_connector() as con:
        with con.cursor() as cur:
            cur.execute('''SELECT user_id, post FROM users
                            INNER JOIN employees USING(employee_id)
                        WHERE login = %s AND hash_password = %s''', (username, password,))
            user = cur.fetchone()
            if not user:
                raise HTTPException(status_code=404, detail='Not Found')
            return {
                    'user_id': user.get('user_id'),
                    'post': user.get('post')
                    }