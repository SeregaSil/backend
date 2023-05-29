/* ТРИГГЕРЫ */
CREATE FUNCTION update_amount_employees() RETURNS TRIGGER AS $$
  BEGIN
    UPDATE establishments
    SET amount_employees = amount_employees + 1
    WHERE establishment_id = NEW.establishment_id;
    RETURN NULL;
  END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_bonus_client() RETURNS TRIGGER AS $$
  DECLARE
    bonus_percent NUMERIC(3,2);
    client_estate VARCHAR(10);
  BEGIN
    SELECT estate INTO client_estate FROM clients WHERE client_id = NEW.client_id;
    IF client_estate = 'Премиум' THEN
      bonus_percent = 0.08;
     ELSIF client_estate = 'Постоянный' THEN
       bonus_percent = 0.05;
     ELSE
       bonus_percent = 0.03;
    END IF;
    UPDATE clients
    SET bonus = bonus + FLOOR((NEW.total_cost) * bonus_percent)
    WHERE client_id = NEW.client_id;
    RETURN NULL;
  END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION update_estate_client() RETURNS TRIGGER AS $$
  BEGIN
    IF NEW.amount_visits > 50 THEN
      NEW.estate := 'Премиум';
    ELSIF NEW.amount_visits > 12 THEN
      NEW.estate := 'Постоянный';
    ELSE
      NEW.estate := 'Обычный';
    END IF;
    RETURN NEW;
  END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION update_amount_visits_client() RETURNS TRIGGER AS $$
  BEGIN
    IF OLD IS NULL THEN
      UPDATE clients
      SET amount_visits = amount_visits + 1
      WHERE client_id = NEW.client_id;
    ELSE 
      UPDATE clients
      SET amount_visits = amount_visits - 1
      WHERE client_id = OLD.client_id;
    END IF;
    RETURN NULL;
  END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION update_total_cost_check() RETURNS TRIGGER AS $$
  BEGIN
    UPDATE checks
    SET total_cost = total_cost + (SELECT cost FROM services WHERE service_id = NEW.service_id)
    WHERE check_id = (SELECT check_id FROM orders WHERE order_id = NEW.order_id);
    RETURN NULL;
  END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION update_rating_employee() RETURNS TRIGGER AS $$
  BEGIN
    UPDATE employees
    SET rating = 
      (
        SELECT ROUND(SUM(grade) / COUNT(grade), 1)
        FROM checks
        WHERE employee_id = NEW.employee_id
      )
    WHERE employee_id = NEW.employee_id;
    RETURN NULL;
  END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION create_new_user() RETURNS TRIGGER AS $$
  DECLARE
    empl_post VARCHAR(13);
    role_name TEXT;
  BEGIN
    SELECT post INTO empl_post FROM employees WHERE employee_id = NEW.employee_id;
    IF empl_post = 'Администратор' THEN
      role_name := format('admin#%s', NEW.employee_id);
      EXECUTE format('CREATE ROLE "%s" WITH LOGIN SUPERUSER INHERIT CREATEROLE', role_name);
      EXECUTE format('GRANT admin TO "%s"', role_name);
    ELSIF empl_post = 'Управляющий' THEN
      role_name := format('control#%s', NEW.employee_id);
      EXECUTE format('CREATE ROLE "%s" WITH LOGIN INHERIT', role_name);
      EXECUTE format('GRANT control TO "%s"', role_name);
    ELSIF empl_post = 'Менеджер' THEN
      role_name := format('manager#%s', NEW.employee_id);
      EXECUTE format('CREATE ROLE "%s" WITH LOGIN INHERIT', role_name);
      EXECUTE format('GRANT manager TO "%s"', role_name);
    ELSIF empl_post = 'Аналитик' THEN
      role_name := format('analyst#%s', NEW.employee_id);
      EXECUTE format('CREATE ROLE "%s" WITH LOGIN INHERIT', role_name);
      EXECUTE format('GRANT analyst TO "%s"', role_name);
    ELSE
      role_name := format('worker#%s', NEW.employee_id);
      EXECUTE format('CREATE ROLE "%s" WITH LOGIN INHERIT', role_name);
      EXECUTE format('GRANT worker TO "%s"', role_name);
    END IF;
    NEW.login = role_name;
    RETURN NEW;
  END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION delete_user() RETURNS TRIGGER AS $$
  BEGIN
    EXECUTE format('DROP ROLE "%s"', OLD.login);
    RETURN NULL;
  END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION hash_user_password() RETURNS TRIGGER AS $$
  BEGIN
    NEW.hash_password = crypt(
      NEW.hash_password,
      (SELECT telephone FROM employees WHERE employee_id = NEW.employee_id)
    );
    RETURN NEW;
  END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER count_employees AFTER
INSERT ON schedule
FOR EACH ROW EXECUTE FUNCTION update_amount_employees();

CREATE OR REPLACE TRIGGER bonus_client AFTER
UPDATE ON checks
FOR EACH ROW
WHEN (NEW.paid is true)
EXECUTE FUNCTION update_bonus_client();

CREATE TRIGGER amount_visits_client AFTER
INSERT OR DELETE ON checks
FOR EACH ROW EXECUTE FUNCTION update_amount_visits_client();

CREATE TRIGGER estate_client AFTER
UPDATE OF amount_visits ON clients
FOR EACH ROW EXECUTE FUNCTION update_estate_client();

CREATE TRIGGER total_cost_check AFTER
INSERT ON orders
FOR EACH ROW EXECUTE FUNCTION update_total_cost_check();

CREATE TRIGGER rating_employee AFTER
UPDATE OF grade ON checks
FOR EACH ROW
WHEN (NEW.grade is not NULL)
EXECUTE FUNCTION update_rating_employee();

CREATE TRIGGER clear_user AFTER
DELETE ON users
FOR EACH ROW EXECUTE FUNCTION delete_user();

CREATE TRIGGER hashing BEFORE
INSERT OR UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION hash_user_password();

CREATE TRIGGER new_user BEFORE
INSERT ON users
FOR EACH ROW EXECUTE FUNCTION create_new_user();

/* ФУНКЦИИ */
CREATE OR REPLACE FUNCTION get_all_checks(find_date date, is_paid BOOLEAN DEFAULT NULL) 
    RETURNS TABLE (
		check_id INTEGER, 
		date_check DATE, 
		total_cost INTEGER, 
        start_time TIME, 
		end_time TIME, 
        paid BOOLEAN, 
		full_name VARCHAR(128), 
		address_establishment VARCHAR(128), 
		post VARCHAR(13),
		client_id INTEGER
) 
AS $$
BEGIN
    RETURN QUERY SELECT 
	checks.check_id, checks.date_check, checks.total_cost, 
	MIN(orders.start_order) as start_time, MAX(orders.end_order) as end_time, 
	checks.paid, employees.full_name, establishments.address_establishment, employees.post, checks.client_id
		FROM checks
		INNER JOIN orders USING(check_id)
		INNER JOIN employees USING(employee_id)
		INNER JOIN schedule USING(employee_id)
		INNER JOIN establishments USING(establishment_id)
	WHERE checks.date_check = schedule.date_work 
		AND (find_date IS NULL OR checks.date_check = find_date)
		AND (is_paid IS NULL OR checks.paid = is_paid)
	GROUP BY checks.check_id, employees.full_name, establishments.address_establishment, employees.post
	ORDER BY checks.date_check DESC, checks.check_id DESC;
END; $$ 
LANGUAGE 'plpgsql';

/* Отчет заведений */
CREATE OR REPLACE FUNCTION establishments_profit_for_period(start_date DATE, end_date DATE)
RETURNS TABLE (
	establishment_id INTEGER, 
	address_establishment VARCHAR(128), 
	profit BIGINT,
	amount_checks INTEGER
) 
AS $$
BEGIN
RETURN QUERY SELECT 
		establishments.establishment_id, establishments.address_establishment, 
		COALESCE(SUM(checks.total_cost), 0) as profit, 
		COUNT(check_id)::INTEGER as amount_checks
		FROM establishments
			 LEFT JOIN schedule USING(establishment_id)
			 LEFT JOIN checks ON checks.employee_id = schedule.employee_id 
							   AND schedule.date_work = checks.date_check
							   AND checks.date_check >= start_date
							   AND checks.date_check <= end_date 
							   AND checks.paid is True
		GROUP BY establishments.establishment_id;
END; $$ 
LANGUAGE 'plpgsql';

/* Отчет сотрудников */
CREATE OR REPLACE FUNCTION employees_profit_for_period(start_date DATE, end_date DATE)
RETURNS TABLE (
	employee_id INTEGER, 
	full_name VARCHAR(128), 
	profit BIGINT,
	period_grade NUMERIC(2,1),
	amount_checks INTEGER
) 
AS $$
BEGIN
RETURN QUERY 
SELECT employees.employee_id, employees.full_name, 
		COALESCE(SUM(checks.total_cost), 0) as profit, 
		COALESCE(ROUND(SUM(checks.grade) / COUNT(checks.grade), 1), 0.0) as period_grade,
		COUNT(check_id)::INTEGER as amount_checks
FROM employees
	 LEFT JOIN checks ON checks.employee_id = employees.employee_id 
	 		AND checks.date_check >= start_date 
			AND checks.date_check <= end_date 
			AND checks.paid is True
WHERE employees.post IN ('Парикмахер')
GROUP BY employees.employee_id;
END; $$ 

LANGUAGE 'plpgsql';


/* Отчет услуг */
CREATE OR REPLACE FUNCTION services_profit_for_period(start_date DATE, end_date DATE)
RETURNS TABLE (
	service_id INTEGER, 
	name_service VARCHAR(50), 
	profit BIGINT,
	amount_checks INTEGER
) 
AS $$
services_plan = plpy.prepare(
	'''SELECT services.service_id, services.name_service, 
		COUNT(checks.check_id) * services.cost as profit, 
		COUNT(checks.check_id)::INTEGER as amount_checks
		FROM services
			LEFT JOIN orders USING(service_id)
			LEFT JOIN checks ON checks.check_id = orders.check_id 
							 AND checks.date_check >= $1  
							 AND checks.date_check <= $2
							 AND checks.paid is True
		GROUP BY services.service_id
		ORDER BY services.service_id;''',
	['date', 'date']
)
services = services_plan.execute([start_date, end_date])
checks_plan = plpy.prepare('''
	SELECT ch.check_id, (SUM(cost) - total_cost) / COUNT(service_id) as paid_bonus, 
	ARRAY (
		SELECT services.service_id
		FROM checks
			INNER JOIN orders USING(check_id)
			INNER JOIN services USING(service_id)
		WHERE checks.check_id = ch.check_id AND ch.paid is True
		GROUP BY checks.check_id, services.service_id
		) as services_id
	FROM checks ch
		INNER JOIN orders USING(check_id)
		INNER JOIN services USING(service_id)
	WHERE ch.paid is True AND ch.date_check >= $1 AND ch.date_check <= $2
	GROUP BY ch.check_id;''',
		['date', 'date'])
checks = checks_plan.execute([start_date, end_date])
for ch in checks:
	for s in services:
		if s['service_id'] in ch['services_id']:
			s['profit'] -= ch['paid_bonus']
return services
$$ 
LANGUAGE 'plpython3u';


CREATE OR REPLACE FUNCTION get_employee_schedule(
	choosen_employee_telephone VARCHAR(18),
	choosen_date DATE,
	choosen_presence BOOLEAN
)
RETURNS TABLE (
	schedule_id INTEGER, 
	date_work DATE, 
	start_work TIME, 
	end_work TIME,
	full_name VARCHAR(128),
	post VARCHAR(13),
	presence BOOLEAN,
	address_establishment VARCHAR(128)
) 
AS $$
BEGIN
RETURN QUERY 
SELECT schedule.schedule_id, schedule.date_work, 
	schedule.start_work, schedule.end_work, 
	employees.full_name, employees.post,
	schedule.presence, establishments.address_establishment
FROM schedule
	INNER JOIN employees USING(employee_id)
	INNER JOIN establishments USING(establishment_id)
WHERE ((choosen_employee_telephone is NULL) OR (choosen_employee_telephone is not NULL AND employees.telephone = choosen_employee_telephone))
	AND ((choosen_date is not NULL AND schedule.date_work >= choosen_date) OR (choosen_date is NULL AND schedule.date_work >= current_date))
	AND ((choosen_presence is not NULL AND schedule.presence = choosen_presence) OR (choosen_presence is NULL))
ORDER BY date_work;
END; $$ 

LANGUAGE 'plpgsql';

/* ПРОЦЕДУРЫ */
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