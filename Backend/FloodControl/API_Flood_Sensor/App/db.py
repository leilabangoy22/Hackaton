from sqlmodel import Session, SQLModel, create_engine
from . import config

settings = config.Settings()

DB_URL = settings.db_string
engine = create_engine(DB_URL)

def get_db():
    with Session(engine) as session:
        yield session

def create_db_and_tables():
    SQLModel.metadata.create_all(engine)