import psycopg2
from psycopg2 import Error
# from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT
from src.core.config import DATABASE_PORT, DATABASE_PASSWORD, DATABASE_HOST, DATABASE_NAME, DATABASE_USER
from fastapi import HTTPException
from starlette import status
from psycopg2.extras import RealDictConnection

def get_connector():
    try:
        connection = psycopg2.connect(
            user=DATABASE_USER, 
            password=DATABASE_PASSWORD,
            database=DATABASE_NAME,
            host=DATABASE_HOST, 
            port=DATABASE_PORT,
            connection_factory=RealDictConnection
        )
        connection.set_client_encoding('UTF8')
        connection.autocommit=False
        return connection
    except (Exception, Error) as error:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail='Incorect user or password')

