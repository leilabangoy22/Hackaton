from fastapi import APIRouter, Depends, Query,  HTTPException
from typing import Annotated, List
from sqlmodel import Session, select
from datetime import datetime

from ..db import get_db
from ..response import Status_Response
from ..schemas import Rescue_Personel_Schema
from ..model import Rescue_Personel, Response, User
from ..dto import rescuer_personnel_dto

dispatcher = APIRouter(prefix='/Rescue_Personel' , tags=['Rescue Personel'])

@dispatcher.get('/', response_model= Rescue_Personel_Schema.Rescue_Personel_SchemaBaseListResponse)
def get_all (db : Session = Depends(get_db), offset : int = 0, limit : Annotated[int, Query(le = 100)]= 100):
    try:
        query_rescue_personel = select(Rescue_Personel).offset(offset).limit(limit)
        db_rescue_personel = db.exec(query_rescue_personel).all()
        if not db_rescue_personel:
            raise HTTPException(status_code=404, detail='No Data Has Been Added')
        return Rescue_Personel_Schema.Rescue_Personel_SchemaBaseListResponse(status_code=200, data=db_rescue_personel)
    except Exception as ex:
        raise  HTTPException(status_code=500, detail=f'An Error "{ex}" Occured')

@dispatcher.get('/{rescue_personel_id}', response_model=Rescue_Personel_Schema.Rescue_Personel_SchemaBaseResponse)
def get_rescue_personel (rescue_personel_id : int, db : Session = Depends(get_db)):
    try:
        db_rescue_personel = db.get(Rescue_Personel, rescue_personel_id)
        if not db_rescue_personel:
            raise HTTPException(status_code=404, detail=f'ID "{rescue_personel_id}" Cannot Be Found')
        return Rescue_Personel_Schema.Rescue_Personel_SchemaBaseResponse(status_code=404, data=db_rescue_personel)
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error "{ex}" Has Been Found')

@dispatcher.get('/Dispatcher/GetRescuerList/{rescue_personnel_id}', response_model=rescuer_personnel_dto.Get_RescuePersonnel_ListResponse)
def get_all_members_rescue_personnel (rescue_personnel_id : int, db : Session = Depends(get_db)):
    try:
        payload : List = []
        get_rescue_personnel = db.get(Rescue_Personel, rescue_personnel_id)
        if not get_rescue_personnel:
            raise HTTPException(status_code=404, detail=f"Rescue Personnel Id {rescue_personnel_id} Cannot Be Found")
        for rescuer_id in get_rescue_personnel.rescuer_id:
            get_rescuer = db.get(User, rescuer_id)
            payload_ = rescuer_personnel_dto.Get_RescuePersonnel_(
                user_id=get_rescuer.user_id,
                name=get_rescuer.name,
                mobile_number=get_rescuer.mobile_number,
                role=get_rescuer.role
            )
            if rescuer_id == get_rescue_personnel.rescuer_id[0]:
                leader = payload_
                continue
            payload.append(payload_)
        return rescuer_personnel_dto.Get_RescuePersonnel_ListResponse(
            status_code=200,
            leader=leader,
            members=payload
        )
    except Exception  as ex:
        raise HTTPException(status_code=200, detail=f'An Error "{ex}" Occuerred')

@dispatcher.post('/', response_model=Rescue_Personel_Schema.Rescue_Personel_SchemaBaseResponse)
def add_rescue_personel(rescue_personel_schema: Rescue_Personel_Schema.Rescue_Personel_SchemaBase, db: Session = Depends(get_db)):
    try:
        for i in rescue_personel_schema.rescuer_id:
            db_rescuer = db.get(User, i)
            if db_rescuer.role != 'Rescuer':
                raise HTTPException(status_code=400, detail=f'User "{db_rescuer.name}" Cannot Be Added As Rescuer')
            if not db_rescuer:
                raise HTTPException(status_code=404, detail=f'Rescuer ID {i} Cannot Be Found')
        rescue_personel = Rescue_Personel(**rescue_personel_schema.model_dump(exclude={'rescue_personel_id'}))
        db.add(rescue_personel)
        db.commit()
        db.refresh(rescue_personel)
        return Rescue_Personel_Schema.Rescue_Personel_SchemaBaseResponse(status_code=200, data=rescue_personel)
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error "{ex}" Occurred')

@dispatcher.put('/{rescue_personel_id}', response_model=Rescue_Personel_Schema.Rescue_Personel_SchemaBaseResponse)
def update_rescue_personel (rescue_personel_schema : Rescue_Personel_Schema.Rescue_Personel_SchemaBase, rescue_personel_id : int, db : Session = Depends(get_db)):
    try:
        query_rescuer_personel = Rescue_Personel.model_validate(rescue_personel_schema)
        db_rescue_personel = db.get(Rescue_Personel, rescue_personel_id)
        for i in rescue_personel_schema.rescuer_id:
            db_rescuer = db.get(User, i)
            if db_rescuer.role != 'Rescuer':
                raise HTTPException(status_code=400, detail=f'User "{db_rescuer.user_id}" Cannot Be Added As Rescuer')
            if not db_rescuer:
                raise HTTPException(status_code=404, detail=f'Rescuer ID {i} Cannot Be Found')
        dump = query_rescuer_personel.model_dump(exclude={'rescuer_personel'}, exclude_unset=True)
        db_rescue_personel.sqlmodel_update(dump)
        db.add(db_rescue_personel)
        db.commit()
        db.refresh(db_rescue_personel)
        return Rescue_Personel_Schema.Rescue_Personel_SchemaBaseResponse(status_code=200, data=db_rescue_personel)
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error "{ex}" Has Occured')

@dispatcher.delete('/', response_model=Status_Response.StatusResponseBase)
def delete_rescuer_personel (rescuer_personel_id : int, db : Session = Depends(get_db)):
    try:
        db_rescuer_personel = db.get(Rescue_Personel, rescuer_personel_id)
        db.delete(db_rescuer_personel)
        db.commit()
        return Status_Response.StatusResponseBase(status_code=200, data= True)
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error "{ex}" Has Occured')