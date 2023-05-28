import locale
import os
from dotenv import load_dotenv


load_dotenv()
locale.setlocale(locale.LC_TIME, 'ru')

DATABASE_HOST = os.environ.get('DATABASE_HOST')
DATABASE_PORT = os.environ.get('DATABASE_PORT')
DATABASE_NAME = os.environ.get('DATABASE_NAME')
DATABASE_USER = os.environ.get('DATABASE_USER')
DATABASE_PASSWORD = os.environ.get('DATABASE_PASSWORD')

SECRET_KEY = os.environ.get('SECRET_KEY')
ALGORITHM = os.environ.get('ALGORITHM')
ACCESS_TOKEN_ALIVE = int(os.environ.get('ACCESS_TOKEN_ALIVE'))
REFRESH_TOKEN_ALIVE = int(os.environ.get('REFRESH_TOKEN_ALIVE'))
