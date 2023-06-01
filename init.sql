/* ТАБЛИЦЫ */
CREATE TABLE clients(
  client_id SERIAL PRIMARY KEY,
  full_name VARCHAR(128) NOT NULL,
  telephone VARCHAR(18) UNIQUE NOT NULL,
  email VARCHAR(255) UNIQUE NULL,
  amount_visits SMALLINT DEFAULT 0 CONSTRAINT positive_amount_visits CHECK (amount_visits >= 0) NOT NULL, /* Триггер*/
  bonus INT DEFAULT 0 CONSTRAINT positive_bonus CHECK (bonus >= 0) NOT NULL, /* Триггер */
  estate VARCHAR(10) DEFAULT 'Обычный' NOT NULL /* Триггер */
);


CREATE TABLE establishments(
  establishment_id SERIAL PRIMARY KEY,
  address_establishment VARCHAR(128) NOT NULL,
  postcode INT NOT NULL,
  telephone VARCHAR(18) UNIQUE NOT NULL,
  amount_employees SMALLINT DEFAULT 0 CONSTRAINT positive_amount_employees CHECK (amount_employees >= 0) NOT NULL /* Триггер */
);

CREATE TABLE employees(
  employee_id SERIAL PRIMARY KEY,
  full_name VARCHAR(128) NOT NULL,
  telephone VARCHAR(18) UNIQUE NOT NULL,
  email VARCHAR(128) UNIQUE NULL,
  experience SMALLINT DEFAULT 0 CONSTRAINT positive_experience CHECK (experience >= 0) NOT NULL,
  salary INT CONSTRAINT positive_salary CHECK (salary > 24800) NOT NULL,
  brief_info TEXT NULL,
  age SMALLINT CONSTRAINT positive_age CHECK (age >= 16 AND 
    age * 365 - experience * 30 >= 16 * 365) NOT NULL,
  post VARCHAR(13) NOT NULL,
  rating NUMERIC(2, 1) CONSTRAINT positive_rating CHECK (rating >= 0 AND rating <= 5) NULL /* Триггер */
);

CREATE TABLE checks(
  check_id SERIAL PRIMARY KEY,
  date_check DATE NOT NULL,
  total_cost INT DEFAULT 0 CONSTRAINT positive_total_cost CHECK (total_cost >= 0) NOT NULL, /* Триггер */
  paid BOOLEAN DEFAULT false NOT NULL,
  grade NUMERIC(2, 1) NULL,
  client_id INT REFERENCES clients ON DELETE SET NULL NULL,
  employee_id INT REFERENCES employees ON DELETE SET NULL NULL
);

CREATE TABLE schedule(
  schedule_id SERIAL PRIMARY KEY,
  date_work DATE NOT NULL,
  start_work TIME NOT NULL,
  end_work TIME NOT NULL CONSTRAINT end_more_than_start CHECK (end_work > start_work),
  presence BOOLEAN DEFAULT true NOT NULL,
  establishment_id INT REFERENCES establishments ON DELETE CASCADE NOT NULL,
  employee_id INT REFERENCES employees ON DELETE CASCADE NOT NULL
);

CREATE TABLE services(
  service_id SERIAL PRIMARY KEY,
  name_service VARCHAR(50) NOT NULL,
  cost SMALLINT CONSTRAINT positive_cost CHECK (cost > 0) NOT NULL,
  duration INTERVAL NOT NULL 
);

CREATE TABLE orders(
  order_id SERIAL PRIMARY KEY,
  start_order TIME NOT NULL,
  end_order TIME NOT NULL,
  check_id INT REFERENCES checks ON DELETE CASCADE NOT NULL,
  service_id INT REFERENCES services NOT NULL
);

CREATE TABLE employee_service(
  employee_id INT REFERENCES employees ON DELETE CASCADE NOT NULL,
  service_id INT REFERENCES services ON DELETE CASCADE NOT NULL,
  PRIMARY KEY (employee_id, service_id)
);

CREATE TABLE users(
  user_id SERIAL PRIMARY KEY,
  login VARCHAR(255) UNIQUE NOT NULL,
  hash_password VARCHAR(255) NOT NULL,
  employee_id INT UNIQUE REFERENCES employees ON DELETE CASCADE NOT NULL 
);

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
      EXECUTE format('CREATE ROLE %I WITH PASSWORD %L LOGIN SUPERUSER INHERIT CREATEROLE', role_name, NEW.hash_password);
      EXECUTE format('GRANT admin TO "%s"', role_name);
    ELSIF empl_post = 'Управляющий' THEN
      role_name := format('control#%s', NEW.employee_id);
      EXECUTE format('CREATE ROLE %I WITH PASSWORD %L LOGIN INHERIT', role_name, NEW.hash_password);
      EXECUTE format('GRANT control TO "%s"', role_name);
    ELSIF empl_post = 'Менеджер' THEN
      role_name := format('manager#%s', NEW.employee_id);
      EXECUTE format('CREATE ROLE %I WITH PASSWORD %L LOGIN INHERIT', role_name, NEW.hash_password);
      EXECUTE format('GRANT manager TO "%s"', role_name);
    ELSIF empl_post = 'Аналитик' THEN
      role_name := format('analyst#%s', NEW.employee_id);
      EXECUTE format('CREATE ROLE %I WITH PASSWORD %L LOGIN INHERIT', role_name, NEW.hash_password);
      EXECUTE format('GRANT analyst TO "%s"', role_name);
    ELSE
      role_name := format('worker#%s', NEW.employee_id);
      EXECUTE format('CREATE ROLE %I WITH PASSWORD %L LOGIN INHERIT', role_name, NEW.hash_password);
      EXECUTE format('GRANT worker TO "%s"', role_name);
    END IF;
    NEW.hash_password = crypt(
      NEW.hash_password,
      (SELECT telephone FROM employees WHERE employee_id = NEW.employee_id)
    );
    NEW.login = role_name;
    RETURN NEW;
  END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION update_user() RETURNS TRIGGER AS $$
  DECLARE
    empl_post VARCHAR(13);
  BEGIN
    EXECUTE format('ALTER ROLE %I WITH PASSWORD %L', OLD.login, NEW.hash_password);
    NEW.hash_password = crypt(
      NEW.hash_password,
      (SELECT telephone FROM employees WHERE employee_id = NEW.employee_id)
    );
    RETURN NEW;
  END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION delete_user() RETURNS TRIGGER AS $$
  BEGIN
    EXECUTE format('DROP ROLE "%s"', OLD.login);
    RETURN NULL;
  END;
$$ LANGUAGE plpgsql;


-- CREATE OR REPLACE FUNCTION hash_user_password() RETURNS TRIGGER AS $$
--   BEGIN
--     NEW.hash_password = crypt(
--       NEW.hash_password,
--       (SELECT telephone FROM employees WHERE employee_id = NEW.employee_id)
--     );
--     RETURN NEW;
--   END;
-- $$ LANGUAGE plpgsql;


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

CREATE TRIGGER new_user BEFORE
INSERT ON users
FOR EACH ROW EXECUTE FUNCTION create_new_user();

CREATE TRIGGER new_user_password BEFORE
UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION update_user();

CREATE TRIGGER clear_user AFTER
DELETE ON users
FOR EACH ROW EXECUTE FUNCTION delete_user();

-- CREATE TRIGGER hashing AFTER
-- INSERT OR UPDATE ON users
-- FOR EACH ROW EXECUTE FUNCTION hash_user_password();


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
							   AND (checks.date_check BETWEEN start_date AND end_date)
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
	 		AND (checks.date_check BETWEEN start_date AND end_date)
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
							 AND (checks.date_check BETWEEN $1 AND $2)
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
	WHERE ch.paid is True AND (ch.date_check BETWEEN $1 AND $2)
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

/* ПОЛЬЗОВАТЕЛИ/РОЛИ */
CREATE ROLE "admin" NOLOGIN SUPERUSER INHERIT CREATEROLE ;
GRANT CONNECT ON DATABASE "barber" TO GROUP "admin"; 
GRANT USAGE ON SCHEMA public TO GROUP "admin";
GRANT ALL ON ALL TABLES IN SCHEMA public TO GROUP "admin";

CREATE ROLE "analyst" NOLOGIN INHERIT ;
GRANT "pg_write_server_files" TO "analyst";
GRANT CONNECT ON DATABASE "barber" TO GROUP "analyst";
GRANT USAGE ON SCHEMA public TO GROUP "analyst";
GRANT SELECT ON ALL TABLES IN SCHEMA public TO GROUP "analyst";

CREATE ROLE "manager" NOLOGIN INHERIT;
GRANT CONNECT ON DATABASE "barber" TO GROUP "manager";
GRANT USAGE ON SCHEMA public TO GROUP "manager";
GRANT INSERT, DELETE ON TABLE 
public.clients, public.checks, public.orders TO GROUP "manager";
GRANT UPDATE(total_cost, paid, grade) ON TABLE public.checks TO GROUP "manager";
GRANT UPDATE(amount_visits, bonus) ON TABLE public.clients TO GROUP "manager";
GRANT UPDATE(rating) ON TABLE public.employees TO GROUP "manager";
GRANT SELECT ON ALL TABLES IN SCHEMA public TO GROUP "manager";
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO GROUP "manager";

CREATE ROLE "worker" NOLOGIN INHERIT;
GRANT CONNECT ON DATABASE "barber" TO GROUP "worker";
GRANT USAGE ON SCHEMA public TO GROUP "worker";
GRANT SELECT ON public.schedule, public.employees, public.establishments, 
public.employee_service, public.services, public.users TO GROUP "worker";

CREATE ROLE "control" NOLOGIN INHERIT;
GRANT CONNECT ON DATABASE "barber" TO GROUP "control"; 
GRANT USAGE ON SCHEMA public TO GROUP "control";
GRANT ALL ON public.establishments, public.schedule, public.employees, 
public.employee_service, public.checks, public.orders, public.clients TO GROUP "control";
GRANT SELECT ON public.users TO GROUP "control";
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO GROUP "control";

/* ПОЛИТИКИ */
ALTER TABLE employee_service ENABLE ROW LEVEL SECURITY;
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE establishments ENABLE ROW LEVEL SECURITY;
ALTER TABLE schedule ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- EMPLOYEE_SERVICE
CREATE POLICY employee_service_for_control ON employee_service
AS PERMISSIVE
FOR ALL
TO control
USING(
	employee_id = ANY(
		SELECT employee_id
		FROM employees
		WHERE post = 'Парикмахер'
  )
)
WITH CHECK(
  employee_id = ANY(
		SELECT employee_id
		FROM employees
		WHERE post = 'Парикмахер'
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

CREATE POLICY employee_service_for_worker ON employee_service
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
		) AND date_work >= current_date
		GROUP BY employee_id
	) 
	OR employee_id not IN(
		SELECT employee_id
		FROM schedule
    WHERE date_work >= current_date
		GROUP BY employee_id
	)
)
WITH CHECK(
  true
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
		 AND date_work >= current_date
		GROUP BY establishment_id
	)
);

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

-- SCHEDULE
CREATE POLICY schedule_for_control ON schedule
AS PERMISSIVE
FOR ALL
TO control
USING(true);

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

-- USERS
CREATE POLICY users_for_all ON users
AS PERMISSIVE
FOR SELECT
USING(
	login = current_user
);

/* ИНДЕКСЫ */
CREATE INDEX order_check_id_index ON orders(check_id);
CREATE INDEX employee_establishment_id_index ON schedule(employee_id, establishment_id);

/* ТЕСТОВЫЕ ДАННЫЕ */
INSERT INTO clients(full_name, telephone, email)
VALUES ('Царёв Иван Иванович', '+7 (916) 489-56-78',	'ivan1970@rambler.ru'), 
      ('Дьякова Ольга Александровна',	'+7 (916) 419-52-28',	'HostileMine@gmail.com'),
      ('Бондарева Мария Артёмовна',	'+7 (924) 481-44-48',	'marina28071981@gmail.com'),
      ('Карасев Пётр Романович',	'+7 (979) 604-27-81',	'petr08081982@mail.ru'),
      ('Селиванова Мария Тихоновна',	'+7 (986) 141-29-60',	'marina24021969@ya.ru'),
      ('Иванова Виктория Мироновна',	'+7 (931) 257-59-25',	'SoaringDuke@gmail.com'),
      ('Дорофеев Павел Владимирович',	'+7 (918) 417-66-73',	'pavel26@gmail.com'),
      ('Шаповалов Василий Кириллович',	'+7 (912) 624-12-58',	'vasiliy12@outlook.com'),
      ('Смирнова Мария Ивановна',	'+7 (941) 443-17-81',	'marina04031991@rambler.ru'),
      ('Суворов Александр Евгеньевич',	'+7 (937) 612-87-19',	'kankenghu@list.ru');

INSERT INTO establishments(address_establishment, postcode, telephone)
VALUES ('г. Москва, ул. Авиаконструктора Яковлева, д.3', '108811',	'+7 (917) 399-94-34'),
      ('г. Москва, бульвар Адмирала Ушакова, д.41',	'107150',	'+7 (911) 952-94-54'),
      ('г. Москва, ул. Энтузиастов 1-я, д.6',	'105082',	'+7 (994) 917-78-29'),
      ('г. Москва, ул. Стромынка, д.20',	'107996',	'+7 (931) 965-97-49');

INSERT INTO employees(full_name, telephone, email, experience, salary, brief_info, age, post)
VALUES ('Бухарова Анфиса Климентьевна',	'+7 (931) 965-97-49',	'anfisa.buharova@rambler.ru',	120,	30000,	'Алкоголичка',	35,	'Уборщик'),
      ('Карнаухова Кира Фадеевна',	'+7 (920) 940-36-43',	'kira1983@hotmail.com',	12,	29000,	'Была судима',	40,	'Уборщик'),
      ('Таттар Григорий Афанасьевич',	'+7 (961) 862-83-98',	'grigoriy98@mail.ru',	39,	30000,	'Спортсмен',	20,	'Уборщик'),
      ('Никерхоев Юрий Ипполитович',	'+7 (918) 885-46-83',	'yuriy1988@gmail.com',	48,	61500,	'Надёжный сотрудник',	31,	'Менеджер'),
      ('Кулдошина Татьяна Марковна',	'+7 (975) 606-91-81',	'tatyana1970@hotmail.com',	0,	33000,	'Новичок',	24,	'Менеджер'),
      ('Балина Лариса Никитьевна',	'+7 (948) 799-16-36',	'larisa2451@mail.ru',	31,	120000,	'Относиться с уважением, решает любые проблемы',	37,	'Управляющий'),
      ('Ефимов Михаил Яковлевич',	'+7 (925) 187-23-82',	'mihail23051996@yandex.ru',	19,	101000,	'Расист',	32,	'Управляющий'),
      ('Рудакова Серафима Романовна',	'+7 (909) 657-23-13',	'serafima50@ya.ru',	9,	97300,	'Трудолюбивая, ответственная',	26,	'Управляющий'),
      ('Масленникова Катерина Феодосьевна',	'+7 (969) 434-47-71',	'katerina7773@ya.ru',	30,	120000,	'Стеснительная, быстро подстраивается под неожиданные ситуации',	35,	'Управляющий'),
      ('Хренов Евгений Тимофеевич', '+7 (921) 948-34-79',	'evgeniy51@outlook.com',	5,	123000,	'Окончил вуз',	24,	'Администратор'),
      ('Мальцева Милана Трофимовна', '+7 (963) 801-98-62',	'milana29@hotmail.com',	10,	110000,	'Новичок',	28,	'Аналитик'),
      ('Куусинен Петр Викторович', '+7 (973) 472-59-17',	'petr9722@yandex.ru',	86,	163200,	'Старший аналитик',	43,	'Аналитик'),
      ('Якимова Варвара Григорьевна', '+7 (956) 254-33-29',	'varvara37@ya.ru',	2,	30000,	'Новичок, закончила престижный колледж',	24,	'Парикмахер'),
      ('Рудавина Галина Панкратовна', '+7 (905) 514-58-90',	'galina1979@rambler.ru',	23,	42120,	'Вышла из дикрета',	27,	'Парикмахер'),
      ('Якухин Даниил Валентинович', '+7 (962) 724-96-61',	'daniil88@mail.ru',	79,	63700,	'Старший парикмахер, профессионал своего дела',	35,	'Парикмахер'),
      ('Семянин Василий Валерьевич', '+7 (929) 843-53-62',	'vasiliy4235@ya.ru',	50,	55840,	'Многодетный отец, разведён, надёжный сотрудник',	33,	'Парикмахер');

INSERT INTO services(name_service, cost, duration)
VALUES ('Стрижка волос наголо', 500, '13M'),
      ('Стрижка простая', 1000, '20M'),
      ('Стрижка модельная', 2000, '30M'),
      ('Стрижка бороды/усов',	700,	'12M'),
      ('Окрашивание',	1100,	'25M'),
      ('Стрижка детская', 800,	'15M'),
      ('Завивка волос',	1500,	'25M'),
      ('Подкрашивание',	600,	'20M'),
      ('Обесцвечивание', 1000,	'16M'),
      ('Укрепление волос', 1000,	'18M'),
      ('Укладка волос после окрашивания',	500,	'7M'),
      ('Укладка',	500,	'7M'),
      ('Мелирование волос',	2500,	'30M'),
      ('Выведение волос из темного цвета в блонд',	2000,	'25M'),
      ('Стрижка челки',	400,	'10M');

INSERT INTO employee_service(employee_id, service_id)
VALUES (15,	1), (15,	2), (15,	3), (15,	4), (15,	5), (15,	6), (15,	7), (15,	8), 
      (15,	9), (15,	10), (15,	11), (15,	12), (15,	13), (15,	14), (15,	15),
      (16,	1), (16,	2), (16,	3), (16,	4), (16,	5), (16,	6), (16,	7), (16,	8), 
      (16,	9), (16,	10), (16,	11), (16,	12), (16,	13), (16,	14), (16,	15),
      (14,	1), (14,	2), (14,	3), (14,	4), (14,	6), (14,	10), (14,	11), (14,	12), (14,	15), 
      (13,	1), (13,	2), (13,	4), (13,	6), (13,	7), (13,	8), (13,	10), (13,	12), (13,	15);

INSERT INTO schedule(date_work, start_work, end_work, presence, establishment_id, employee_id)
VALUES ('07-20-2023', '8:00:00', '17:00:00', true, 1, 1),
      ('07-20-2023', '14:00:00', '23:00:00', true, 1, 2), 
      ('07-20-2023', '8:00:00', '17:00:00', true, 2, 1), 
      ('07-20-2023', '14:00:00', '23:00:00', true, 2, 3),
      ('07-21-2023', '8:00:00', '17:00:00', true, 3, 2),
      ('07-21-2023', '14:00:00', '23:00:00', true, 3, 1),
      ('07-21-2023', '8:00:00', '17:00:00', true, 4, 2), 
      ('07-21-2023', '14:00:00', '23:00:00', true, 4, 3),
      ('07-20-2023', '9:00:00', '22:00:00', true, 1, 4), /* Менеджер 4 */
      ('07-20-2023', '9:00:00', '22:00:00', true, 1, 6), /* Управляющий 6 только в 1 */
      ('07-20-2023', '9:00:00', '22:00:00', true, 2, 7), /* Управляющий 7 только в 2 */
      ('07-21-2023', '9:00:00', '22:00:00', true, 3, 5), /* Менеджер 5 */
      ('07-21-2023', '9:00:00', '22:00:00', true, 3, 8), /* Управляющий 8 только в 3 */
      ('07-21-2023', '9:00:00', '22:00:00', true, 4, 9), /* Управляющий 9 только в 4 */
      ('07-20-2023', '12:00:00', '20:00:00', true, 1, 10), /* Администратор */
      ('07-21-2023', '12:00:00', '20:00:00', true, 3, 10), /* Администратор */
      ('07-21-2023', '8:00:00', '22:00:00', true, 2, 11), /* Аналитик */
      ('07-21-2023', '8:00:00', '22:00:00', true, 4, 12), /* Аналитик */
      ('07-20-2023', '9:00:00', '18:00:00', true, 1, 15), /* Парикмахер 15 */
      ('07-20-2023', '13:00:00', '22:00:00', true, 2, 16), /* Парикмахер 16 */
      ('07-20-2023', '9:00:00', '18:00:00', true, 1, 13), /* Парикмахер 13 */
      ('07-20-2023', '13:00:00', '22:00:00', true, 2, 14), /* Парикмахер 14 */
      ('07-21-2023', '9:00:00', '18:00:00', true, 3, 15), /* Парикмахер 15 */
      ('07-21-2023', '13:00:00', '22:00:00', true, 4, 16), /* Парикмахер 16 */
      ('07-21-2023', '9:00:00', '18:00:00', true, 3, 13), /* Парикмахер 13 */
      ('07-21-2023', '13:00:00', '22:00:00', true, 4, 14); /* Парикмахер 14 */

INSERT INTO users(hash_password, employee_id)
VALUES ('admin', 10),
        ('w1', 1),
        ('a11', 11),
        ('m4', 4),
        ('c8', 8)

-- COPY (SELECT * FROM employees_profit_for_period('2020-01-01', '2023-01-01')) TO '/tmp/employee_report.csv' 
-- DELIMITER ',' CSV HEADER;