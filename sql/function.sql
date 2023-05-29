-- CREATE FUNCTION create_order_client(start_order TIME, ) RETURNS TRIGGER AS $$
--   BEGIN

--     INSERT checks(date_check, client_id)
--   END;
-- $$ LANGUAGE plpgsql;

/* Функция удаления чека */


/* Для страничек */
-- SELECT name_service, cost, duration
-- FROM services;

-- SELECT full_name, experience, rating
-- FROM employees
-- WHERE rating IS NOT NULL;

-- SELECT date_work, employees.full_name, establishments.establishment_id
-- FROM schedule 
--       INNER JOIN employees USING(employee_id)
--       INNER JOIN establishments USING(establishment_id)
-- WHERE employees.position = 'Парикмахер'
-- ORDER BY date_work, establishments.establishment_id, employees.full_name;


/* Получение последних (по дате чека) 5 чеков*/
CREATE OR REPLACE FUNCTION get_last_five_checks_by_client_id(find_client_id integer, find_date date, is_paid BOOLEAN DEFAULT NULL) 
    RETURNS TABLE (
		check_id INTEGER, 
		date_check DATE, 
		total_cost INTEGER, 
        start_time TIME, 
		end_time TIME, 
        paid BOOLEAN, 
		full_name VARCHAR(128), 
		address_establishment VARCHAR(128), 
		post VARCHAR(13)
) 
AS $$
BEGIN
    RETURN QUERY SELECT 
	checks.check_id, checks.date_check, checks.total_cost, 
	MIN(orders.start_order) as start_time, MAX(orders.end_order) as end_time, 
	checks.paid, employees.full_name, establishments.address_establishment, employees.post
		FROM checks
		INNER JOIN orders USING(check_id)
		INNER JOIN employees USING(employee_id)
		INNER JOIN schedule USING(employee_id)
		INNER JOIN establishments USING(establishment_id)
	WHERE checks.client_id = find_client_id AND checks.date_check = schedule.date_work 
		AND (find_date IS NULL OR checks.date_check = find_date)
		AND (is_paid IS NULL or checks.paid = is_paid)
	GROUP BY checks.check_id, employees.full_name, establishments.address_establishment, employees.post
	ORDER BY checks.date_check DESC, checks.check_id DESC
	LIMIT 5;
END; $$ 
LANGUAGE 'plpgsql';



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

/* Отчет заведений/заведения */
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

/* Отчет сотрудников/сотрудника */
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


/* Отчет услуг/услуги */
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