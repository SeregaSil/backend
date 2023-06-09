/*
--ACCESS DB
REVOKE CONNECT ON DATABASE nova FROM PUBLIC;
GRANT  CONNECT ON DATABASE nova  TO user;

--ACCESS SCHEMA
REVOKE ALL     ON SCHEMA public FROM PUBLIC;
GRANT  USAGE   ON SCHEMA public  TO user;

--ACCESS TABLES
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC ;
GRANT SELECT                         ON ALL TABLES IN SCHEMA public TO read_only ;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO read_write ;
GRANT ALL                            ON ALL TABLES IN SCHEMA public TO admin ; 
*/


CREATE ROLE "admin" NOLOGIN SUPERUSER INHERIT NOCREATEDB CREATEROLE NOREPLICATION;
GRANT CONNECT ON DATABASE "barber" TO GROUP "admin"; 
GRANT USAGE ON SCHEMA public TO GROUP "admin";
GRANT ALL ON ALL TABLES IN SCHEMA public TO GROUP "admin";

CREATE ROLE "analyst" NOLOGIN NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION;
GRANT CONNECT ON DATABASE "barber" TO GROUP "analyst";
GRANT USAGE ON SCHEMA public TO GROUP "analyst";
GRANT SELECT ON ALL TABLES IN SCHEMA public TO GROUP "analyst";

CREATE ROLE "manager" NOLOGIN NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION;
GRANT CONNECT ON DATABASE "barber" TO GROUP "manager";
GRANT USAGE ON SCHEMA public TO GROUP "manager";
GRANT INSERT, DELETE ON TABLE 
public.clients, public.checks, public.orders TO GROUP "manager";
GRANT UPDATE(total_cost, paid)  ON TABLE public.checksTO GROUP "manager";
-- GRANT UPDATE(amount_visits, bonus, estate) ON TABLE public.clients TO GROUP "manager";
-- GRANT UPDATE(rating) ON TABLE public.employees TO GROUP "manager";
GRANT SELECT ON ALL TABLES IN SCHEMA public TO GROUP "manager";

CREATE ROLE "worker" NOLOGIN NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION;
GRANT CONNECT ON DATABASE "barber" TO GROUP "worker";
GRANT USAGE ON SCHEMA public TO GROUP "worker";
GRANT SELECT ON public.schedule, public.employees, public.establishments, 
public.employee_service, public.services, public.users TO GROUP "worker";

CREATE ROLE "control" NOLOGIN NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION;
GRANT CONNECT ON DATABASE "barber" TO GROUP "control"; 
GRANT USAGE ON SCHEMA public TO GROUP "control";
GRANT ALL ON public.establishments, public.schedule, public.employees, 
public.employee_service, public.checks, public.orders, public.clients TO GROUP "control";
GRANT SELECT ON public.users TO GROUP "control";

-- CREATE POLICY test_policy ON checks
-- FOR UPDATE
-- USING(paid is false)
-- WITH CHECK(paid is true)