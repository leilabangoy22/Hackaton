
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from google import genai


from .settings import Settings # -- Remote
from .Router import ai_group_route
setting = Settings() # -- remote


# from Router import ai_group_route
# from config import Setting # -- Remote


from fastapi.middleware.cors import CORSMiddleware


setting = Settings() # -- local

@asynccontextmanager
async def lifespan(app: FastAPI):
    try: 
        app.state.gemini_client = genai.Client(
            api_key=setting.gemini_key
        )
        yield
        app.state.gemini_client.close()
    except Exception as e:
        print(f"Failed to create DB tables: {e}")


app = FastAPI(lifespan=lifespan)


app.add_middleware(
    CORSMiddleware,
    # allow_origins=["http://localhost:4200"],  # Angular Focus ----  TEMPORARY MWEHEHEH
    allow_origins=["*"],  # Allows all origins for testing
    allow_credentials=True,
    allow_methods=["*"],  # Allows all HTTP methods
    allow_headers=["*"],  # Allows all headers
)

app.include_router(ai_group_route.ai)