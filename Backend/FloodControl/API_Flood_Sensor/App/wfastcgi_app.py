# <import>: ASGI → WSGI converter
from asgiref.wsgi import AsgiToWsgi

# <import>: your FastAPI ASGI app (from app.py)
from main import app  # "app" is the ASGI FastAPI instance

# <conversion>: wrap the ASGI app into a WSGI-compatible interface
application = AsgiToWsgi(app)
