from datetime import date, datetime
from fastapi import Depends, FastAPI, Request, Response
from fastapi.responses import JSONResponse
from psycopg2.errors import UniqueViolation, CheckViolation, InsufficientPrivilege
from psycopg2._psycopg import connection

from src.database import get_connector
from fastapi.openapi.docs import get_swagger_ui_html
from fastapi.staticfiles import StaticFiles
from src.routers import (auth, test, specialist, 
                         check, client, service, 
                         establishment, employee, schedule)

from fastapi import Depends, FastAPI
from fastapi.openapi.docs import get_swagger_ui_html
from fastapi.middleware.cors import CORSMiddleware

from starlette.middleware.sessions import SessionMiddleware


app = FastAPI(title='Barber', docs_url=None, redoc_url=None)
app.add_middleware(SessionMiddleware, secret_key="some-random-string", max_age=None)

origins = ['http://localhost:3000', 'http://127.0.0.1:3000',
           'https://localhost:3000', 'https://127.0.0.1:3000', 'http://25.52.40.15', 'http://25.39.159.67'] 

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=['*'],
    allow_headers=['*'],
)

app.mount("/static", StaticFiles(directory="static"), name="static")

app.include_router(specialist.router)
app.include_router(auth.router)
app.include_router(check.router)
app.include_router(client.router)
app.include_router(service.router)
app.include_router(establishment.router)
app.include_router(test.router)
app.include_router(employee.router)
app.include_router(schedule.router)

@app.get("/docs", include_in_schema=False)
async def swagger_ui_html():
    return get_swagger_ui_html(
        openapi_url="/openapi.json",
        title="Barber",
        swagger_favicon_url="/static/favicon-16x16.ico"
    )

            
@app.get('/ping')
def create_db(req: Request):
    with get_connector() as con:
        with con.cursor() as cur:
            cur.execute(open('sql/table.sql', 'r', encoding="utf-8").read())
            cur.execute(open('sql/trigger.sql', 'r', encoding="utf-8").read())
            cur.execute(open('sql/insert.sql', 'r', encoding="utf-8").read())
            cur.execute(open('sql/function.sql', 'r', encoding="utf-8").read())
            cur.execute(open('sql/procedure.sql', 'r', encoding="utf-8").read())
            cur.execute(open('sql/users.sql', 'r', encoding="utf-8").read())
    return {'status': 200}

@app.get('/insert')
def test_insert_into_db():
    with get_connector() as con:
        with con.cursor() as cur:
            cur.execute(open('sql/insert_for_tests.sql', 'r', encoding="utf-8").read())
            con.commit()
    return {'status': 200}

@app.exception_handler(UniqueViolation)
def UniqueViolation_exception_handler(request: Request, exc: UniqueViolation):
    return JSONResponse(
        status_code=409,
        content={"message": "Не уникальные данные"},
    )
    
@app.exception_handler(CheckViolation)
def CheckViolation_exception_handler(request: Request, exc: CheckViolation):
    return JSONResponse(
        status_code=406,
        content={"message": "Неприемлемые данные"},
    )
    
@app.exception_handler(InsufficientPrivilege)
def InsufficientPrivilege_exception_handler(request: Request, exc: InsufficientPrivilege):
    return JSONResponse(
        status_code=403,
        content={"message": "В разрешении отказано"},
    )