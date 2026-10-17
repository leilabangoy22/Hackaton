from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
# from starlette.middleware.sessions import SessionMiddleware
import os


from .db import create_db_and_tables
from .router import Location_Router, Report_Router, Rescue_Personel_Router, Response_Router, User_Router, Dispatcher_Dashboard_Router, google_place_search_route, Flood_Sensor,Data_Forward_Router


# # Define role-based access control (RBAC) structure
# RESOURCES_FOR_ROLES = {
#     'Dispatcher': {
#         'accounts': ['read', 'write', 'delete'],
#         'reports' : ['read','update','delete'],
#         'response' : ['read', ]
#     },
#     'User': {
#         'resource1': ['read', 'write'],
#     },
    
# }

@asynccontextmanager
async def lifespan(app : FastAPI): # app : FastAPI --> to use later if I might want access to the FastAPI app instance if certain setup or teardown conditions require item(index) 
    try:
        create_db_and_tables()
        print("Tables created.")
        yield
        print("Exiting-With A ")
    except Exception as e:
        print(f"Failed to create DB tables: {e}")

app = FastAPI(lifespan=lifespan)


@app.get("/") # <route>
async def home(): # <method>
    return {"message": "Hello from FastAPI running under IIS!"}


app.add_middleware(
    CORSMiddleware,
    # allow_origins=["http://localhost:4200"],  # Angular Focus ----  TEMPORARY MWEHEHEH
    allow_origins=["*"],  # Allows all origins but not specified
    allow_credentials=True,
    allow_methods=["*"],  # Allows all HTTP methods
    allow_headers=["*"],  # Allows all headers
)



app.include_router(Location_Router.user)
app.include_router(Report_Router.user)
app.include_router(Rescue_Personel_Router.dispatcher)
app.include_router(Response_Router.dispatcher)
app.include_router(User_Router.user)
app.include_router(User_Router.dispatcher)
app.include_router(Dispatcher_Dashboard_Router.dispatcher)
app.include_router(User_Router.rescuer)
app.include_router(google_place_search_route.user)
app.include_router(Flood_Sensor.sensor)
app.include_router(Report_Router.dispatcher)
app.include_router(Data_Forward_Router.module)

"""
Do Later:
    Fix Location
    Instantiate Role

"""