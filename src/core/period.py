import datetime
from typing import List


def create_time_range(cur, employee_id: int, establishment_id: int, services: List[int]):
    cur.execute('''SELECT date_work, start_work, end_work
                        FROM employees
                            INNER JOIN schedule USING(employee_id)
                        WHERE employees.post IN ('Парикмахер') AND presence is True
                            AND establishment_id = %s
                        AND employee_id = %s''', (establishment_id, employee_id,))
    employee_schedule = cur.fetchall()
    
    cur.execute('''SELECT date_check, MIN(start_order) as start_time, MAX(end_order) as end_time
                    FROM orders
                        INNER JOIN checks USING(check_id)
                    WHERE employee_id = %s
                    GROUP BY checks.check_id
                    ORDER BY MIN(start_order)''', (employee_id,))
    orders_intervals = cur.fetchall()
    
    cur.execute('''SELECT SUM(duration) as duration
                    FROM services
                    WHERE service_id IN %s;''', (tuple(services),))
    duration = cur.fetchone().get('duration')
    schedule = []
    for i in range(len(employee_schedule)):
            breaks = [dict(x) for x in orders_intervals if x.get('date_check') == employee_schedule[i].get('date_work')]
            times = []
            start = datetime.datetime.combine(datetime.date.today(), employee_schedule[i].get('start_work'))
            end = datetime.datetime.combine(datetime.date.today(), employee_schedule[i].get('end_work'))
            period = start    
            while period + duration <= end:
                times.append(period)
                period += datetime.timedelta(minutes=15)
            # schedule.append(EmployeePeriod(
            #     date=employee_schedule[i].get('date_work'), 
            #     times=clear_interval(breaks, times, duration, end))
            # )
            schedule.append({
                'date': employee_schedule[i].get('date_work'), 
                'times': clear_interval(breaks, times, duration, end)
            })
    return schedule

def clear_interval(breaks, times: List[datetime.time], duration, end_work):
    res = []
    if breaks == []:
        for t in times:
            if (t <= end_work) and \
                (t + duration <= end_work):
                res.append(t)
        times = res.copy()
    else:
        for j in range(len(breaks)):
            start = datetime.datetime.combine(datetime.date.today(), breaks[j].get('start_time'))
            end = datetime.datetime.combine(datetime.date.today(), breaks[j].get('end_time'))
            for t in times:
                if not (t >= start and t <= end) and \
                     (t + duration <= start or t + duration >= end) and \
                        not (t <= start and t + duration >= end) and \
                        (t <= end_work) and \
                        (t + duration <= end_work):
                    res.append(t)
            times = res.copy()
            res.clear()
    return times 