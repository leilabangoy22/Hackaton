from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi import Request, HTTPException 

import auth_handler

class JWTBearer(HTTPBearer):
    async def __call__(self, request):
        return await super().__call__(request)