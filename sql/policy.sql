
-- Create or REPLACE view current_employees_id_for_control AS
-- SELECT employee_id
-- 		FROM schedule
-- 		WHERE establishment_id = ANY(
-- 			SELECT establishment_id
-- 			FROM schedule
-- 			WHERE employees.employee_id::text = substring(current_user from '[0-9]+')
-- 		) AND date_work = ANY(
-- 			SELECT date_work
-- 			FROM schedule
-- 			WHERE schedule.employee_id::text = substring(current_user from '[0-9]+')
-- 				AND date_work >= current_date
-- 		)
-- 		GROUP BY employee_id;

-- CHECKS
-- CREATE POLICY checks_for_control ON checks
-- AS PERMISSIVE
-- FOR ALL
-- TO control
-- USING(true)

-- CREATE POLICY checks_for_analyst ON checks
-- AS PERMISSIVE
-- FOR SELECT
-- TO analyst
-- USING(true);

-- CREATE POLICY checks_for_manager ON checks
-- AS PERMISSIVE
-- FOR ALL
-- TO manager
-- USING(true);

-- CLIENTS
-- CREATE POLICY clients_for_control ON clients
-- AS PERMISSIVE
-- FOR ALL
-- TO control
-- USING(true);

-- CREATE POLICY clients_for_analyst ON clients
-- AS PERMISSIVE
-- FOR SELECT
-- TO analyst
-- USING(true);

-- CREATE POLICY clients_for_manager ON clients
-- AS PERMISSIVE
-- FOR ALL
-- TO manager
-- USING(true);

-- EMPLOYEE_SERVICE
CREATE POLICY employee_service_for_control ON employee_service
AS PERMISSIVE
FOR ALL
TO control
USING(
	employee_id = ANY(
		SELECT employee_id
		FROM schedule
		WHERE establishment_id = ANY(
			SELECT establishment_id
			FROM schedule
			WHERE schedule.employee_id::text = substring(current_user from '[0-9]+')
			GROUP BY establishment_id
		) AND date_work = ANY(
			SELECT date_work
			FROM schedule
			WHERE schedule.employee_id::text = substring(current_user from '[0-9]+')
				AND date_work >= current_date
		)
		GROUP BY employee_id;
	)
);

CREATE POLICY employee_service_for_analyst ON employee_service
AS PERMISSIVE
FOR SELECT
TO analyst
USING(true);

CREATE POLICY employee_service_for_manager ON employee_service
AS PERMISSIVE
FOR SELECT
TO manager
USING(true);

CREATE POLICY employees_for_worker ON employees
AS PERMISSIVE
FOR SELECT
TO worker
USING(
	employee_id::text = substring(current_user from '[0-9]+')
);

-- EMPLOYEES
CREATE POLICY employees_for_control ON employees
AS PERMISSIVE
FOR ALL
TO control
USING(
	employee_id = ANY(
		SELECT employee_id
		FROM schedule
		WHERE establishment_id = ANY(
			SELECT establishment_id
			FROM schedule
			WHERE schedule.employee_id::text = substring(current_user from '[0-9]+')
			GROUP BY establishment_id
		) AND date_work = ANY(
			SELECT date_work
			FROM schedule
			WHERE schedule.employee_id::text = substring(current_user from '[0-9]+')
				AND date_work >= current_date
		)
		GROUP BY employee_id;
	)
);

CREATE POLICY employees_for_worker ON employees
AS PERMISSIVE
FOR SELECT
TO worker
USING(
	employee_id::text = substring(current_user from '[0-9]+')
);

CREATE POLICY employees_for_analyst ON employees
AS PERMISSIVE
FOR SELECT
TO analyst
USING(true);

CREATE POLICY employees_for_manager ON employees
AS PERMISSIVE
FOR SELECT
TO manager
USING(
	post = 'Парикмахер' OR
	employee_id::text = substring(current_user from '[0-9]+')
);

-- ESTABLISHMENTS
CREATE POLICY establishments_for_control ON establishments
AS PERMISSIVE
FOR ALL
TO control
USING(
	establishment_id = ANY(
		SELECT establishment_id
		FROM schedule
		WHERE employee_id::text = substring(current_user from '[0-9]+')
		 AND date_work = ANY(
			SELECT date_work
			FROM schedule
			WHERE schedule.employee_id::text = substring(current_user from '[0-9]+')
				AND date_work >= current_date
		)
		GROUP BY establishment_id;
	)
);

-- Срабатывает другая политика?
CREATE POLICY establishments_for_worker ON establishments
AS PERMISSIVE
FOR SELECT
TO worker
USING(
	establishment_id = ANY (
		SELECT establishment_id
		FROM schedule
	)
);

CREATE POLICY establishments_for_analyst ON establishments
AS PERMISSIVE
FOR SELECT
TO analyst
USING(true);

CREATE POLICY establishments_for_manager ON establishments
AS PERMISSIVE
FOR SELECT
TO manager
USING(true);

-- ORDERS
-- Срабатывает другая политика?
-- CREATE POLICY orders_for_control ON orders
-- AS PERMISSIVE
-- FOR ALL
-- TO control
-- USING(
-- 	check_id = ANY(
-- 		SELECT check_id
-- 		FROM checks
-- 	)
-- );

-- CREATE POLICY orders_for_analyst ON orders
-- AS PERMISSIVE
-- FOR SELECT
-- TO analyst
-- USING(true);

-- CREATE POLICY orders_for_manager ON orders
-- AS PERMISSIVE
-- FOR ALL
-- TO manager
-- USING(true);

-- SCHEDULE
-- ???????????????????????
CREATE POLICY schedule_for_control ON schedule
AS PERMISSIVE
FOR ALL
TO control
USING(
	true
);

CREATE POLICY schedule_for_worker ON schedule
AS PERMISSIVE
FOR SELECT
TO worker
USING(
	employee_id::text = substring(current_user from '[0-9]+')
);

CREATE POLICY schedule_for_analyst ON schedule
AS PERMISSIVE
FOR SELECT
TO analyst
USING(true);

-- Срабатывает другая политика?
CREATE POLICY schedule_for_manager ON schedule
AS PERMISSIVE
FOR SELECT
TO manager
USING(
	employee_id = ANY(
		SELECT employee_id
		FROM employees
	) OR
	employee_id::text = substring(current_user from '[0-9]+')
);

-- SERVICES
-- CREATE POLICY services_for_control ON services
-- AS PERMISSIVE
-- FOR ALL
-- TO control
-- USING(true);

-- CREATE POLICY services_for_analyst ON services
-- AS PERMISSIVE
-- FOR SELECT
-- TO analyst
-- USING(true);

-- CREATE POLICY services_for_manager ON services
-- AS PERMISSIVE
-- FOR SELECT
-- TO manager
-- USING(true);

-- USERS
CREATE POLICY users_for_all ON users
AS PERMISSIVE
FOR SELECT
USING(
	login = current_user
);