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
      bonus_percent = 8 / 100;
     ELSIF client_estate = 'Постоянный' THEN
       bonus_percent = 5 / 100;
     ELSE
       bonus_percent = 3 / 100;
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

-- CREATE FUNCTION correct_start_and_time_order() RETURNS TRIGGER AS $$
--    DECLARE
--     past_end_time TIME;
--   BEGIN
--     past_end_time := 
--       (
--         SELECT end_order
--         FROM orders
--         WHERE order_id = 
--           (
--             SELECT order_id
--             FROM orders
--             WHERE check_id = (SELECT check_id FROM orders WHERE order_id = NEW.order_id)
--             ORDER BY start_order DESC
--             LIMIT 1
--           )
--       );

--     IF (SELECT start_order FROM orders WHERE order_id = NEW.order_id) = '00:00:00' THEN
--       UPDATE orders
--       SET start_order = past_end_time + '00:05:00',
--           end_order = past_end_time + '00:05:00' + (SELECT duration FROM services WHERE service_id = NEW.service_id)
--       WHERE order_id = NEW.order_id;
--     ELSE
--       UPDATE orders
--       SET end_order = start_order + (SELECT duration FROM services WHERE service_id = NEW.service_id)
--       WHERE order_id = NEW.order_id;
--     END IF;
--     RETURN NULL;
--   END;
-- $$ LANGUAGE plpgsql;

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
-- Работает
CREATE TRIGGER count_employees AFTER
INSERT ON schedule
FOR EACH ROW EXECUTE FUNCTION update_amount_employees();

-- Работает
CREATE TRIGGER bonus_client AFTER
UPDATE OF paid ON checks
FOR EACH ROW
WHEN (NEW.paid = true)
EXECUTE FUNCTION update_bonus_client();

-- Работает
CREATE TRIGGER estate_client BEFORE
UPDATE ON clients
FOR EACH ROW EXECUTE FUNCTION update_estate_client();

-- Работает
CREATE TRIGGER amount_visits_client AFTER
INSERT OR DELETE ON checks
FOR EACH ROW EXECUTE FUNCTION update_amount_visits_client();

-- Работает (не надо)
-- CREATE TRIGGER start_and_time_order AFTER
-- INSERT ON order_service
-- FOR EACH ROW EXECUTE FUNCTION correct_start_and_time_order();

-- Работает
CREATE TRIGGER total_cost_check AFTER
INSERT ON orders
FOR EACH ROW EXECUTE FUNCTION update_total_cost_check();

-- Работает
CREATE TRIGGER rating_employee AFTER
UPDATE ON checks
FOR EACH ROW EXECUTE FUNCTION update_rating_employee();

CREATE TRIGGER clear_user AFTER
DELETE ON users
FOR EACH ROW EXECUTE FUNCTION delete_user();

CREATE TRIGGER hashing BEFORE
INSERT OR UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION hash_user_password();

CREATE TRIGGER new_user BEFORE
INSERT ON users
FOR EACH ROW EXECUTE FUNCTION create_new_user();
