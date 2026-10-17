Install this following package:
```
pip install fastapi uvicorn sqlmodel sqlalchemy psycopg2-binary python-jose passlib[bcrypt] httpx starlette

```

To run migration, move to the parent folder of alembic, then:
``` 
alembic revision --autogenerate -m "<Migration Name>"
```

To upgrade head of migration:
```
alembic upgrade head
```

To run the app, move to the parent folder of main, then:
```
uvicorn main:app --reload
```