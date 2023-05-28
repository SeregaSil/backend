DROP SCHEMA public CASCADE;
CREATE SCHEMA public;


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
  rating NUMERIC(2, 1) CONSTRAINT positive_rating CHECK (rating >= 0 AND rating <= 5) NULL, /* Триггер */
  system_login VARCHAR(20) UNIQUE NULL
);

CREATE TABLE checks(
  check_id SERIAL PRIMARY KEY,
  date_check DATE NOT NULL,
  total_cost INT DEFAULT 0 CONSTRAINT positive_total_cost CHECK (total_cost >= 0) NOT NULL, /* Триггер */
  paid BOOLEAN DEFAULT false NOT NULL,
  grade NUMERIC(1) NULL,
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
  start_order TIME DEFAULT '00:00:00' NOT NULL, /* Триггер */
  end_order TIME DEFAULT '00:00:00' NOT NULL, /* Триггер */
  check_id INT REFERENCES checks ON DELETE CASCADE NOT NULL,
  service_id INT REFERENCES services NOT NULL /* ON DELETE ?*/
);

-- CREATE TABLE order_service(
--   order_id INT REFERENCES orders ON DELETE CASCADE NOT NULL,
--   service_id INT REFERENCES services ON DELETE CASCADE NOT NULL,
--   PRIMARY KEY (order_id)
-- );

CREATE TABLE employee_service(
  employee_id INT REFERENCES employees ON DELETE CASCADE NOT NULL,
  service_id INT REFERENCES services ON DELETE CASCADE NOT NULL,
  PRIMARY KEY (employee_id, service_id)
);

-- CREATE TABLE check_employee(
--   check_id INT REFERENCES checks ON DELETE CASCADE NOT NULL,
--   employee_id INT REFERENCES employees ON DELETE CASCADE NOT NULL,
--   PRIMARY KEY (check_id)
-- );


CREATE TABLE users(
  user_id SERIAL PRIMARY KEY,
  login VARCHAR(255) UNIQUE NOT NULL,
  hash_password VARCHAR(255) NOT NULL,
  employee_id INT REFERENCES employees ON DELETE CASCADE NOT NULL 
);