from fastapi import APIRouter, Depends, Query, HTTPException, Request
from typing import Annotated, List
from sqlmodel import Session, select, and_
from datetime import datetime

from ..db import get_db
from ..schemas import Report_Schema
from ..model import Report, Location, Response, User, Rescue_Personel
from ..response import Status_Response
from ..dto import report_dto, rescuer_personnel_dto
from ..service.fallback_service import fallback_serviceClass

user = APIRouter(prefix='/User/Report', tags=['Report'])
dispatcher = APIRouter(prefix='/Dispatcher/Report', tags=['Report'])

@user.get('/', response_model=Report_Schema.Report_SchemaBaseListResponse)
def get_all_report(db: Session = Depends(get_db), offset : int = 0, limit : Annotated[int, Query(le=100)] = 100):
    try:
        query_report = select(Report).offset(offset).limit(limit)
        db_report = db.exec(query_report).all()
        
        payload_list : List | None = []
        if not db_report:
            raise HTTPException(status_code=404, detail='No Report Has Been Added')
        for report in db_report:
            get_user = db.get(User, report.user_id)
            get_dispatcher = db.get(User, report.dispatcher_id)
            payload = Report_Schema.Report_SchemaBase(
                report_id=report.report_id,
                location_id=report.location_id,
                user_id=report.user_id,
                user_phone_number=get_user.mobile_number if get_user.mobile_number else None,
                dispatcher_id=report.dispatcher_id,
                dispatcher_phone_number=get_dispatcher.mobile_number if get_dispatcher else None,
                user_name=get_user.name if get_user.name else None,
                severity=report.severity,
                rescue_personnel_id=report.rescue_personnel_id,
                assigned_to=report.assigned_to,
                title=report.title,
                flood_height=report.flood_height,
                explanation=report.explanation,
                response_status=report.response_status,
                response_id=report.response_id,
                report_status=report.report_status,
                created_by=report.created_by,
                created_at=report.created_at,
                updated_at=report.updated_at,
                updated_by=report.updated_by
            )
            payload_list.insert(0, payload)
        return Report_Schema.Report_SchemaBaseListResponse(status_code=200, data=payload_list)
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error "{ex}" Occured')

@user.get('/{report_id}', response_model=Report_Schema.Report_SchemaBaseResponse)
def get_report_by_id(report_id : int , db:Session = Depends(get_db)):
    try:
        report = db.get(Report, report_id)
        if not report:
            raise HTTPException(status_code=404, detail=f'Id "{report_id}" Cannot Be Found')
        if not report:
            raise HTTPException(status_code=404, detail='No Report Has Been Added')
        get_user = db.get(User, report.user_id)
        get_dispatcher = db.get(User, report.dispatcher_id)
        get_user = db.get(User, report.user_id)
        get_dispatcher = db.get(User, report.dispatcher_id)
        payload = Report_Schema.Report_SchemaBase(
            report_id=report.report_id,
            location_id=report.location_id,
            user_id=report.user_id,
            user_phone_number=get_user.mobile_number if get_user.mobile_number else None,
            dispatcher_id=report.dispatcher_id,
            dispatcher_phone_number=get_dispatcher.mobile_number if get_dispatcher else None,
            user_name=get_user.name if get_user.name else None,
            severity=report.severity,
            rescue_personnel_id=report.rescue_personnel_id,
            assigned_to=report.assigned_to,
            title=report.title,
            flood_height=report.flood_height,
            explanation=report.explanation,
            response_status=report.response_status,
            response_id=report.response_id,
            report_status=report.report_status,
            created_by=report.created_by,
            created_at=report.created_at,
            updated_at=report.updated_at,
            updated_by=report.updated_by
        )
        return Report_Schema.Report_SchemaBaseResponse(status_code=200, data=payload)
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error "{ex}" Occured')


@user.post('/{user_id}', response_model=Report_Schema.Report_SchemaBaseResponse)
def add_report(report_schema : Report_Schema.Report_SchemaBase,user_id : int,db : Session = Depends(get_db)):
    try: 
        get_location = db.get(Location, report_schema.location_id)
        if not get_location:
            raise HTTPException (status_code=404, detail=f'Location ID "{report_schema.location_id}" Cannot Be Found')
        if report_schema.flood_height < 0:
            raise HTTPException(status_code=400, detail=f'Bad Request! {report_schema.flood_height} Data Should be Greated Than 0')
        get_dispatcher = db.exec(select(User).where(and_(User.user_id == report_schema.dispatcher_id, User.role == "Dispatcher"))).first()
        get_dispatcher_number = report_schema.dispatcher_phone_number if report_schema.dispatcher_phone_number != 'string' else (get_dispatcher.mobile_number if get_dispatcher.mobile_number else None)
        get_user = db.get(User, user_id)        
        if not get_user :
            raise HTTPException(status_code=404, detail='No User Has Been Found')
        get_user_number = report_schema.user_phone_number if report_schema.user_phone_number != 'string' else (get_user.mobile_number if get_user.mobile_number else None)
        sqldata = Report(
            rescue_personnel_id=report_schema.rescue_personnel_id,
            dispatcher_id =report_schema.dispatcher_id,
            assigned_to=report_schema.assigned_to,
            location_id=report_schema.location_id,
            user_id=user_id,
            title=report_schema.title,
            flood_height=report_schema.flood_height,
            explanation=report_schema.explanation,
            response_status="Pending",
            report_status="Pending",
            created_by=get_user.name,
            created_at=datetime.now(),
            updated_by=get_user.name,
            updated_at=datetime.now()
        )
        db.add(sqldata)
        db.commit()
        db.refresh(sqldata)
        payload = Report_Schema.Report_SchemaBase(
            rescue_personnel_id=report_schema.rescue_personnel_id,
            assigned_to=report_schema.assigned_to,
            dispatcher_id=report_schema.dispatcher_id,
            dispatcher_phone_number=get_dispatcher_number,
            report_id=sqldata.report_id,
            user_name = get_user.name,
            user_phone_number=get_user_number,
            location_id=report_schema.location_id,
            user_id=user_id,
            title=report_schema.title,
            flood_height=report_schema.flood_height,
            explanation=report_schema.explanation,
            response_status="Pending",
            report_status="Pending",
            created_by=get_user.name,
            created_at=datetime.now(),
            updated_by=get_user.name,
            updated_at=datetime.now()
        )
        return Report_Schema.Report_SchemaBaseResponse(status_code=200, data=payload)
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error "{ex}" Occured')

@user.put('/{report_id}', response_model=Report_Schema.Report_SchemaBaseResponse)
def update_report(report_id : int, report_schema : Report_Schema.Report_SchemaBase, user_id : int,db : Session = Depends(get_db)):
    try:
        query_report = Report.model_validate(report_schema)
        db_report = db.get(Report, report_id)
        get_user = db.get(User, user_id)
        if not get_user:
            raise HTTPException(status_code=404, detail='User Cannot Be Found')
        db_report.updated_by = get_user.name
        db_report.updated_at = datetime.now()
        dump = query_report.model_dump(exclude={'report_id'}, exclude_unset=True)
        db_report.sqlmodel_update(dump)
        db.add(db_report)
        db.commit()
        db.refresh(db_report)
        return Report_Schema.Report_SchemaBaseResponse(status_code=200, data=db_report)
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error "{ex}" Occured')



@dispatcher.put('/AddResponse/{report_id}', response_model=Report_Schema.Report_SchemaBaseResponse)
def add_response_by_dispatcher(report_id: int, user_id: int, addresponse: Report_Schema.AddResponse_Schema, db: Session = Depends(get_db)):
    try:
        get_report = db.get(Report, report_id)
        if not get_report:
            raise HTTPException(status_code=404, detail=f'Report Id "{report_id}" Cannot Be Found')
        get_user = db.get(User, get_report.user_id)
        if not get_user:
            raise HTTPException(status_code=404, detail='Report Owner User Cannot Be Found')
        get_dispatcher = db.get(User, user_id)
        if not get_dispatcher:
            raise HTTPException(status_code=404, detail=f'Dispatcher Id {user_id} Cannot Be Found')
        get_assigned_by = db.exec(
            select(User).where(and_(User.user_id == addresponse.assigned_to, User.role == "Rescuer"))
        ).first()
        if addresponse.assigned_to and not get_assigned_by:
            raise HTTPException(status_code=404, detail=f"Rescuer Id {addresponse.assigned_to} Cannot Be Found")
        get_report.dispatcher_id = fallback_serviceClass.fallback(user_id, get_report.dispatcher_id)
        get_report.response_id = fallback_serviceClass.fallback(addresponse.response_id, get_report.response_id)
        get_report.severity = fallback_serviceClass.fallback(addresponse.severity, get_report.severity)
        get_report.rescue_personnel_id = fallback_serviceClass.fallback(addresponse.rescue_personnel_id, get_report.rescue_personnel_id)
        get_report.report_status = fallback_serviceClass.fallback(addresponse.report_status, get_report.report_status)
        get_report.assigned_to = fallback_serviceClass.fallback(addresponse.assigned_to, get_report.assigned_to)
        get_report.updated_at = datetime.now()
        get_report.updated_by = fallback_serviceClass.fallback(get_dispatcher.name, get_report.updated_by)
        get_report.response_status = fallback_serviceClass.fallback(addresponse.response_status, get_report.response_status)

        db.commit()
        db.refresh(get_report)

        payload = Report_Schema.Report_SchemaBase(
            report_id = get_report.report_id,
            location_id = get_report.location_id,
            user_id = get_report.user_id,
            user_phone_number = get_user.mobile_number if get_user else None,
            dispatcher_id = get_report.dispatcher_id,
            dispatcher_phone_number = get_dispatcher.mobile_number if get_dispatcher else None,
            user_name = get_user.name if get_user else None,
            severity = get_report.severity,
            rescue_personnel_id = get_report.rescue_personnel_id,
            assigned_to = get_report.assigned_to,
            title = get_report.title,
            flood_height = get_report.flood_height,
            explanation = get_report.explanation,
            response_status = get_report.response_status,
            response_id = get_report.response_id,
            report_status = get_report.report_status,
            created_by = get_report.created_by,
            created_at = get_report.created_at,
            updated_by = get_report.updated_by,
            updated_at = get_report.updated_at
        )

        return Report_Schema.Report_SchemaBaseResponse(status_code=200, data=payload)

    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error "{ex}" Occurred')


@user.delete('/', response_model=Status_Response.StatusResponseBase)
def delete_report (report_id : int, db : Session = Depends(get_db)):
    try:
        db_report = db.get(Report, report_id)
        if not db_report:
            raise HTTPException(status_code=404, detail=f'Id "{report_id}" Cannot Be Found')
        db.delete(db_report)
        db.commit()
        return Status_Response.StatusResponseBase(status_code=200, data=True)
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error "{ex}" Occured')