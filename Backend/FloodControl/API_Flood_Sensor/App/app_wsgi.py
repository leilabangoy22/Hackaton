from main import app as fastapi_app
from a2wsgi import ASGIMiddleware

# Convert FastAPI (ASGI) to WSGI callable
app = ASGIMiddleware(fastapi_app)
