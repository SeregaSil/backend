from datetime import date, datetime
from fastapi import Depends, FastAPI, Request, Response
from fastapi.responses import JSONResponse
from psycopg2.errors import UniqueViolation, CheckViolation, InsufficientPrivilege, ObjectInUse
from psycopg2._psycopg import connection

from src.database import get_connector
from fastapi.openapi.docs import get_swagger_ui_html
from fastapi.staticfiles import StaticFiles
from src.routers import (auth, specialist, 
                         check, client, service, 
                         establishment, employee, schedule)

from fastapi import Depends, FastAPI
from fastapi.openapi.docs import get_swagger_ui_html
from fastapi.middleware.cors import CORSMiddleware

from starlette.middleware.sessions import SessionMiddleware


app = FastAPI(title='Barber', docs_url=None, redoc_url=None)
app.add_middleware(SessionMiddleware, secret_key="some-random-string", max_age=None)

origins = ['http://localhost:3000', 'http://127.0.0.1:3000',
           'https://localhost:3000', 'https://127.0.0.1:3000'] 

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
app.include_router(employee.router)
app.include_router(schedule.router)

@app.get("/docs", include_in_schema=False)
async def swagger_ui_html():
    return get_swagger_ui_html(
        openapi_url="/openapi.json",
        title="Barber",
        swagger_favicon_url="/static/favicon-16x16.ico"
    )

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
    
@app.exception_handler(ObjectInUse)
def ObjectInUse_exception_handler(request: Request, exc: ObjectInUse):
    return JSONResponse(
        status_code=412,
        content={"message": "Неприемлемые данные"},
    )