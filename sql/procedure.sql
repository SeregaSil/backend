/* Запись */
CREATE OR REPLACE PROCEDURE insert_check(
	order_date DATE,
	order_client_id INTEGER,
	order_services_id INTEGER[],
	order_employee_id INTEGER,
	order_start_time TIME
)
AS $$
from datetime import time, datetime, timedelta

def str_to_timedelta(str_time):
	t = datetime.strptime(str_time, '%H:%M:%S')
	return timedelta(hours=t.hour, minutes=t.minute, seconds=t.second)

start_time = str_to_timedelta(order_start_time)

check_plan = plpy.prepare(
	'''INSERT INTO checks(date_check, client_id, employee_id)
		VALUES($1, $2, $3)
		RETURNING check_id''', 
	['date', 'integer', 'integer']
)

orders_plan = plpy.prepare(
	'''INSERT INTO orders(start_order, end_order, check_id, service_id)
    	VALUES($1, $2, $3, $4)
    	RETURNING order_id''',
	['time', 'time', 'integer', 'integer']
)

end_time_plan = plpy.prepare(
	'''SELECT duration
		FROM services
		WHERE service_id = $1''',
	['integer']
)
with plpy.subtransaction():
	check_id = check_plan.execute([order_date, order_client_id, order_employee_id], 1)[0]['check_id']
	for ser_id in order_services_id:
		end_time = str_to_timedelta(end_time_plan.execute([ser_id])[0]['duration']) + start_time
		order_id = orders_plan.execute([start_time, end_time, check_id, ser_id])[0]['order_id']
		start_time = end_time
$$
LANGUAGE 'plpython3u';



-- CREATE OR REPLACE PROCEDURE update_client(
-- 	cl_id INTEGER,
-- 	new_full_name VARCHAR(128),
-- 	new_telephone VARCHAR(18),
-- 	new_email VARCHAR(255)
-- )
-- AS $$
-- client_info_plan = plpy.prepare(
-- 	'''SELECT full_name, telephone, email 
-- 	FROM clients
-- 	WHERE client_id = $1''',
-- 	['integer']
-- )
-- client_info = client_info_plan.execute([cl_id], 1)[0]
-- if client_info['full_name'] != new_full_name and new_full_name is not None:
-- 	client_info['full_name'] = new_full_name
-- if client_info['telephone'] != new_telephone and new_telephone is not None:
-- 	client_info['telephone'] = new_telephone
-- if client_info['full_name'] != new_email and new_email is not None:
-- 	client_info['email'] = new_email
-- new_client_info = plpy.prepare(
-- 	'''UPDATE clients
-- 	SET full_name = $1,
-- 		telephone = $2,
-- 		email = $3
-- 	WHERE client_id = $4''',
-- 	['varchar(128)', 'varchar(18)', 'varchar(255)', 'integer']
-- )
-- new_client_info.execute([
-- 	client_info['full_name'],
-- 	client_info['telephone'],
-- 	client_info['email'],
-- 	cl_id
-- ])
-- $$
-- LANGUAGE 'plpython3u';
-- order_employee_plan = plpy.prepare(
-- 	'''INSERT INTO order_employee(order_id, employee_id)
--     	VALUES($1, $2)''',
-- 	['integer', 'integer']
-- )
        -- order_employee_plan.execute([order_id, order_employee_id])