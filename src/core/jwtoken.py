from jose import jwt, JWTError
from jose.exceptions import ExpiredSignatureError
from .config import SECRET_KEY, ALGORITHM, ACCESS_TOKEN_ALIVE, REFRESH_TOKEN_ALIVE
from datetime import datetime, timedelta
from fastapi import HTTPException, status


def create_token(data: dict, token_type: str):
    to_encode = data.copy()
    if token_type == 'access_token':
        to_encode.update({
		'exp': datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_ALIVE),
		'sub': token_type
	})
    elif token_type == 'refresh_token':
        to_encode.update({
		'exp': datetime.utcnow() + timedelta(days=REFRESH_TOKEN_ALIVE),
		'sub': token_type
	})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt


def decode_access_token(token, exception):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get('sub') != "access_token":
            raise exception
        user_id: int = payload.get("user_id")
        if user_id is None:
            raise exception
        return user_id
    except ExpiredSignatureError:
        raise HTTPException(status_code=status.HTTP_426_UPGRADE_REQUIRED,
                            detail='Token expired! Please update token!')
    except JWTError:
        raise exception


def decode_refresh_token(token, exception):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get('sub') != "refresh_token":
            raise exception
        user_id: int = payload.get("user_id")
        if user_id is None:
            raise exception
        return user_id
    except ExpiredSignatureError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED,
                            detail='Token expired! Please login in your accout again!')
    except JWTError:
        raise exception

def get_all_tokens(data: dict):
    access_token = create_token(data, 'access_token')
    refresh_token = create_token(data, 'refresh_token')

    response = {
        'access_token': access_token,
        'refresh_token': refresh_token
    }
    
    return response
