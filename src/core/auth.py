# import datetime
# from typing import Dict, Optional 
# from fastapi import Depends, HTTPException, Request

# from uuid import UUID, uuid4
# from fastapi.security import OAuth2
# from fastapi.openapi.models import OAuthFlows as OAuthFlowsModel
# from pydantic import BaseModel
# from starlette import status
# from starlette.requests import Request
# from psycopg2._psycopg import connection
# from src.database import get_connector
# from fastapi.security.utils import get_authorization_scheme_param

# class SessionData:
#     def __init__(self, conn, role):
#         self.date_time: datetime.datetime = datetime.datetime.now()
#         self.connector: connection = conn
#         self.role: str = role

# class OAuth2PasswordCookie(OAuth2):
#     def __init__(
#         self,
#         tokenUrl: str,
#         scheme_name: str = None,
#         scopes: dict = None,
#         auto_error: bool = True,
#     ):
#         if not scopes:
#             scopes = {}
#         flows = OAuthFlowsModel(password={'tokenUrl': tokenUrl, 'scopes': scopes})
#         super().__init__(flows=flows, scheme_name=scheme_name, auto_error=auto_error)

#     async def __call__(self, request: Request) -> Optional[str]:
#         header_authorization: str = request.headers.get('Authorization')
#         cookie_authorization: str = request.cookies.get('barber_id')

#         header_scheme, header_param = get_authorization_scheme_param(
#             header_authorization
#         )

#         if header_scheme.lower() == 'bearer':
#             authorization = True
#             scheme = header_scheme
#             param = header_param
#         elif cookie_authorization:
#             authorization = True
#             param = cookie_authorization
#         else:
#             authorization = False

#         if not authorization or scheme.lower() != 'bearer':
#             if self.auto_error:
#                 raise HTTPException(
#                     status_code=403, detail='Not authenticated'
#                 )
#             else:
#                 return None
#         return param

#         # cookie_authorization: str = request.cookies.get("barber")
#         # print(cookie_authorization)
#         # if not cookie_authorization:
#         #     return get_connector(user='client', password='789')
#         #     # raise HTTPException(
#         #     #     status_code=status.HTTP_403_FORBIDDEN, detail="Not authenticated"
#         #     #     )

#         # connector: connection = self.sessions.get(UUID(cookie_authorization))
        
#         # if not connector:
#         #     authorization = False

#         # else:
#         #     authorization = True

#         # if not authorization:
#         #     return get_connector(user='client', password='789')
#         #     # if self.auto_error:
#         #     #     raise HTTPException(
#         #     #         status_code=status.HTTP_403_FORBIDDEN, detail="Not authenticated"
#         #     #     )
#         #     # else:
#         #     #     return None
#         # return connector

# oauth2_scheme = OAuth2PasswordCookie(tokenUrl='/login')

# sessions: Dict[UUID, SessionData] = {}

# def get_current_user(token: str = Depends(oauth2_scheme)) -> SessionData:
#     return sessions.get(token)
    
# def new_session(connection, role):
#     id = uuid4()
#     sessions[id] = SessionData(connection, role)
#     return str(id)

# def close_session(token: str):
#     id = UUID(token)
#     sessions.get(id).connector.close()
#     del sessions[id]


from src.database import get_connector

from typing import Annotated
from fastapi import Depends, HTTPException
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError
from starlette import status
from psycopg2._psycopg import connection
from .jwtoken import decode_access_token, decode_refresh_token

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="login")


def get_current_connector(token: Annotated[str, Depends(oauth2_scheme)],
                           con: connection = Depends(get_connector)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        user_id = decode_access_token(token, credentials_exception)
        with get_connector() as con:
            with con.cursor() as cur:
                cur.execute('''SELECT login FROM users WHERE user_id = %s''', (user_id,))
                role = cur.fetchone()
                if not role:
                    raise credentials_exception
                cur.execute('''SET ROLE %s;''', (role.get('login'), ))
        return con
    except JWTError:
        raise credentials_exception


# async def get_current_user_by_refresh(token: Annotated[str, Depends(oauth2_scheme)],
#                                       con: connection = get_connector()):
#     credentials_exception = HTTPException(
#         status_code=status.HTTP_401_UNAUTHORIZED,
#         detail="Could not validate credentials",
#         headers={"WWW-Authenticate": "Bearer"},
#     )
#     try:
#         user_id = decode_refresh_token(token, credentials_exception)
#         user = await get_by_id(user_id, db)
#         if user is None or user.token != token:
#             raise credentials_exception
#         return user
#     except JWTError:
#         raise credentials_exception
