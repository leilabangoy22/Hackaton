from datetime import datetime, timedelta
from jose import jwt, JWTError

SECRET_KEY = "kanade" # Will Add OS soon to cover and put it in ignore
ALGORITHM = "HS256"

def create_access_token(data : dict, expires_at : timedelta = timedelta(hours=1)):
    to_encode = data
    to_encode.update({"exp" : datetime.now() + expires_at})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

def verify_access_token(token : str):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=ALGORITHM)
        return payload
    except JWTError:
        return None 