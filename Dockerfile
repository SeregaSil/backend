FROM postgres:15.2

RUN apt-get update && \
    apt-get -y install postgresql-plpython3-15

COPY extension.sql /docker-entrypoint-initdb.d