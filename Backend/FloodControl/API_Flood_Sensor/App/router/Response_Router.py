from fastapi import APIRouter, Depends, Query, HTTPException, Request
from typing import Annotated
from sqlmodel import Session, select
from datetime import datetime

from ..db import get_db
from ..schemas import Response_Schema
from ..model import Response, User, Report, Rescue_Personel
from ..response import Status_Response

dispatcher = APIRouter(prefix='/Response', tags=['Response'])

@dispatcher.get('/', response_model=Response_Schema.Response_SchemaBaseListResponse)
def get_all_response(db: Session = Depends(get_db), offset : int = 0, limit : Annotated[int, Query(le=100)] = 100):
    try:
        query_response = select(Response).offset(offset).limit(limit)
        db_response = db.exec(query_response).all()
        if not db_response:
            raise HTTPException(status_code=404, detail='No Response Has Been Added')
        return Response_Schema.Response_SchemaBaseListResponse(status_code=200, data=db_response)
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error "{ex}" Occured')

@dispatcher.get('/{response_id}', response_model=Response_Schema.Response_SchemaBaseResponse)
def get_response_by_id(response_id : int , db:Session = Depends(get_db)):
    try:
        db_response = db.get(Response, response_id)
        if not db_response:
            raise HTTPException(status_code=404, detail=f'Id "{response_id}" Cannot Be Found')
        return Response_Schema.Response_SchemaBaseResponse(status_code=200, data=db_response)
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error "{ex}" Occured')

@dispatcher.post('/{user_id}', response_model=Response_Schema.Response_SchemaBaseResponse)
def add_response(user_id : int, report_id : int,response_schema : Response_Schema.Response_SchemaBase, db : Session = Depends(get_db)):
    try: 
        get_report = db.get(Report, report_id)
        if not get_report:
            raise HTTPException(status_code=404, detail=f"Report {report_id} Cannot Be Found")
        get_rescue_personel = db.get(Rescue_Personel, response_schema.rescue_personel_id)
        if not get_rescue_personel:
            raise HTTPException(status_code=404, detail='No Rescue Personel Found')

        get_user = db.get(User, user_id)
        response_schema.created_by = get_user.name
        response_schema.created_at = datetime.now()
        response_schema.updated_by = get_user.name
        response_schema.updated_at = datetime.now()
        response = Response(**response_schema.model_dump(exclude={'response_id'}))
        db.add(response)
        db.commit()
        db.refresh(response)
        get_report.response_id = response.response_id
        db.add(get_report)
        db.commit()
        return Response_Schema.Response_SchemaBaseResponse(status_code=200, data=response)
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error "{ex}" Occured')

@dispatcher.put('/{response_id}/{user_id}', response_model=Response_Schema.Response_SchemaBaseResponse)
def update_response(user_id : int, response_id : int,response_schema : Response_Schema.Response_SchemaBase, db : Session = Depends(get_db)):
    try:
        query_response = Response.model_validate(response_schema)
        db_response = db.get(Response, response_id)
        db_response.updated_at = datetime.now()
        get_rescue_personel = db.get(Rescue_Personel, response_schema.rescue_personel_id)
        if not get_rescue_personel:
            raise HTTPException(status_code=404, detail='No Rescue Personel Found')
        get_user = db.get(User, user_id)
        if not get_user:
            raise HTTPException(status_code=404, detail='User Cannot Be Found')
        db_response.updated_by = get_user.name
        if not db_response:
            raise HTTPException(status_code=404,detail=f'Id "{response_id}" Cannot Be Found')
        dump = query_response.model_dump(exclude={'response_id'}, exclude_unset=True)
        db_response.sqlmodel_update(dump)
        db.add(db_response)
        db.commit()
        db.refresh(db_response)
        return Response_Schema.Response_SchemaBaseResponse(status_code=200, data=db_response)
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error "{ex}" Occured')

@dispatcher.delete('/', response_model=Status_Response.StatusResponseBase)
def delete_response(response_id : int, db : Session = Depends(get_db)):
    try:
        db_response = db.get(Response, response_id)
        if not db_response:
            raise HTTPException(status_code=404, detail='Response Cannot Be Found')
        db.delete(db_response)
        db.commit()
        return Status_Response.StatusResponseBase(status_code=200, data=True)
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error {ex} Occurred')