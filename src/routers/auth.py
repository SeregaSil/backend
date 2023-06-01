from typing import Annotated
from fastapi import APIRouter, Depends,HTTPException, Request, Response, Cookie
from fastapi.responses import JSONResponse
from psycopg2._psycopg import connection
# from src.core.auth import get_current_user, new_session, SessionData, close_session

from src.database import get_connector
from fastapi.security import OAuth2PasswordRequestForm

from starlette.responses import Response, JSONResponse


router = APIRouter(tags=['Auth'])

# @router.post('/login')
# def login(response: Response, form: OAuth2PasswordRequestForm = Depends()):
#     try:
#         conn = get_connector(user=form.username, password=form.password)
#         with conn:
#             with conn.cursor() as cur:
#                 cur.execute('SELECT full_name, telephone, email, post FROM employees WHERE system_login = %s', 
#                             (form.username,))
#                 empl = cur.fetchone()
#                 session_id = new_session(conn, empl.get('post'))
#                 response = JSONResponse(status_code=200, content=empl)
#                 response.set_cookie(key='barber_id', value=session_id)
#                 return response
#     except Exception as ex:
#         raise ex


# @router.post('/logout')
# def logout(response: Response, request: Request, session: SessionData = Depends(get_current_user)):
#     try:
#         close_session(request.cookies.get('session_id'))
#         response.delete_cookie('barber_id')
#         response = JSONResponse(status_code=200, content={'message': 'Logout success'})
#         return response
#     except Exception as e:
#         print(e)
#         raise HTTPException(status_code=404, detail='Not authenticated')

from src.core.jwtoken import create_token

@router.post('/login')
def login(request: OAuth2PasswordRequestForm = Depends(), conn: connection = Depends(get_connector)):
    with conn as con:
        with con.cursor() as cur:
            cur.execute('''SELECT user_id, full_name, telephone, email, post, employee_id FROM users
                            INNER JOIN employees USING(employee_id)
                        WHERE login = %s AND hash_password = crypt(%s, hash_password)''', (request.username, request.password,))
            user = cur.fetchone()
            if not user:
                raise HTTPException(status_code=404, detail='Incorect username or password')
            token = create_token(data={"user_id": user.get('user_id')}, token_type='access_token')
            return {
                    'full_name': user.get('full_name'),
                    'telephone': user.get('telephone'),
                    'email': user.get('email'),
                    'post': user.get('post'),
                    'access_token': token,
                    'user_id': user.get('employee_id')
                    }