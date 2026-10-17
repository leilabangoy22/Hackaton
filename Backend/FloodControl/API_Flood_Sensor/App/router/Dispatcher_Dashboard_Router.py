from fastapi import APIRouter, Depends, HTTPException   
from typing import Annotated
from sqlmodel import Session, select, func

from ..db import get_db
from ..dto import dashboard_dto, rescuer_dto,detailed_report
from ..response import Status_Response
from ..model import Report, User, Response, Location
from ..schemas import Report_Schema, User_Schema

dispatcher  = APIRouter(prefix='/Dispatcher/Operation', tags=['Operation'])

@dispatcher.get('/Number_of_Status', response_model=dashboard_dto.request_statusBaseResponse)
def get_request(db : Session = Depends(get_db)):
    try:
        total_pending = db.exec(select(func.count()).select_from(Report).where(func.lower(Report.response_status) == "pending")).one()
        total_assigned = db.exec(select(func.count()).select_from(Report).where(func.lower(Report.response_status) == "assigned")).one()
        total_completed = db.exec(select(func.count()).select_from(Report).where(func.lower(Report.response_status) == "completed")).one()
        data_ = dashboard_dto.request_statusBase(
            pending = total_pending,
            assigned=total_assigned,
            completed=total_completed
        )
        return dashboard_dto.request_statusBaseResponse(status_code=200, data= data_)
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error "{ex}" Occured')

@dispatcher.get('/All_Pending_Request', response_model=Report_Schema.Report_SchemaBaseListResponse)
def get_all_pending_report(db : Session = Depends(get_db)):
    try:
        all_pending = db.exec(select(Report).where(func.lower(Report.response_status) == "pending")).all()
        if not all_pending:
            raise HTTPException(status_code=404,detail="No Pending Request")
        return Report_Schema.Report_SchemaBaseListResponse(status_code=200,data=all_pending)
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error "{ex}" Occured')

@dispatcher.get('/Personel_List', response_model=rescuer_dto.Rescuer_ListBaseListResponse)
def get_all_rescuer(db:Session = Depends(get_db)):
    try:
        get_rescuer = db.exec(select(User).where(User.role == "Rescuer")).all()
        if not get_rescuer:
            raise HTTPException(status_code=404, detail="No Rescuer Has Been Added")
        return rescuer_dto.Rescuer_ListBaseListResponse(status_code=200, data=get_rescuer)
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error "{ex}" Occured')