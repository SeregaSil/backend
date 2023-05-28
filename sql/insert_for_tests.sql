/* Проверка начисления бонусов */
-- INSERT INTO checks(date_check, total_cost, client_id)
-- VALUES ('04-20-2023', 10000, 3),
--       ('04-20-2023', 4500, 9),
--       ('04-20-2023', 700, 3),
--       ('05-20-2023', 100, 3),
--       ('04-20-2023', 15000, 7);

-- UPDATE checks
-- SET total_cost = 1000,
--     paid = true
-- WHERE check_id = 4;


/* Проверка изменения статуса */
-- UPDATE clients
-- SET amount_visits = 51
-- WHERE client_id = 7;


/* Проверка добавления окончания выполнения заказа */
-- INSERT INTO checks(date_check, total_cost, client_id)
-- VALUES ('04-20-2023', 10000, 3);

-- INSERT INTO orders(start_order, check_id)
-- VALUES ('17:00:00', 1);

-- INSERT INTO order_service(order_id, service_id)
-- VALUES (1, 5)


/* Проверка обновления окончательной суммы чека */
-- INSERT INTO checks(date_check, client_id)
-- VALUES ('04-20-2023', 3), ('04-20-2023', 6);

-- INSERT INTO orders(start_order, check_id)
-- VALUES ('17:00:00', 1);

-- INSERT INTO orders(check_id)
-- VALUES (1), (1), (1);

-- INSERT INTO order_service(order_id, service_id)
-- VALUES (1, 5), (2, 7), (3, 14), (4, 11);

-- INSERT INTO orders(start_order, check_id)
-- VALUES ('10:00:00', 2);

-- INSERT INTO orders(check_id)
-- VALUES (2);

-- INSERT INTO order_service(order_id, service_id)
-- VALUES (5, 5), (6, 6);

-- INSERT INTO orders(start_order, check_id)
-- VALUES ('19:00:00', 1);

-- INSERT INTO orders(check_id)
-- VALUES (1);

-- INSERT INTO order_service(order_id, service_id)
-- VALUES (7, 1), (8, 3);


/* Проверка обновления рейтинга у работников */
-- INSERT INTO checks(date_check, total_cost, client_id)
-- VALUES ('04-20-2023', 10000, 3);

-- INSERT INTO orders(start_order, check_id)
-- VALUES ('17:00:00', 1);

-- INSERT INTO orders(check_id)
-- VALUES (1), (1), (1), (1);

-- INSERT INTO order_employee(order_id, employee_id)
-- VALUES (1, 15), (2, 14), (3, 15), (4, 16), (5, 15);

-- UPDATE orders
-- SET grade = 5
-- WHERE order_id = 1;

-- UPDATE orders
-- SET grade = 1
-- WHERE order_id = 2;

-- UPDATE orders
-- SET grade = 4
-- WHERE order_id = 3;

-- UPDATE orders
-- SET grade = 2
-- WHERE order_id = 4;

-- UPDATE orders
-- SET grade = 5
-- WHERE order_id = 5;
