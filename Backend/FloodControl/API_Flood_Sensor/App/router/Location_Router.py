from fastapi import APIRouter, Depends, Query, HTTPException
from typing import Annotated
from sqlmodel import Session, select

from ..db import get_db
from ..schemas import Location_Schema
from ..model import Location, Report
from ..response import Status_Response
from ..dto import google_place_search_dto

user = APIRouter(prefix='/Location', tags=['Location'])

@user.get('/', response_model=Location_Schema.Location_SchemaBaseListResponse)
def get_all_location(db: Session = Depends(get_db), offset : int = 0, limit : Annotated[int, Query(le=100)] = 100):
    try:
        query_location = select(Location).offset(offset).limit(limit)
        db_location = db.exec(query_location).all()
        if not db_location: 
            raise HTTPException(status_code=404, detail='No Location Has Been Added')
        return Location_Schema.Location_SchemaBaseListResponse(status_code=200, data=db_location)
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error "{ex}" Occured')

@user.get("/Rescuer_Location", response_model=google_place_search_dto.RescueLocationResponseBase)
async def get_rescuer_location(rescuer_location_schema : google_place_search_dto.RescuerLocation = Query(..., description="Distance is in Meters, and Speed is in meters per second"), db : Session = Depends(get_db)):
    try:
        get_report_location = db.get(Report, rescuer_location_schema.report_id)
        if not get_report_location:
            raise HTTPException(status_code=404, detail=f"No Report With Report Id {rescuer_location_schema} Has Been Found")
        get_location = db.get(Location, get_report_location.location_id)
        if not get_location:
            raise HTTPException(status_code=404, detail=f"No Report With Report Id {rescuer_location_schema} Has Been Found")
        time = rescuer_location_schema.distance/ 13.89
        hours = time // 3600
        minutes = (time % 3600) // 60
        seconds = time % 60
        time_str = f"{hours}h {(minutes)}m {round(seconds, 2)}s Left For Arrival"
        payload = google_place_search_dto.RescuerLocationresponse(
            latitude_rescuer=rescuer_location_schema.latitude,
            longitude_rescuer=rescuer_location_schema.longitude,
            latitude_report=get_location.latitude,
            longitude_report=get_location.longitude,
            distance=rescuer_location_schema.distance,
            time_arrival=time_str
        )
        return google_place_search_dto.RescueLocationResponseBase(status_code=200, data=payload)
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error "{ex}" Occured')

@user.get('/{location_id}', response_model=Location_Schema.Location_SchemaBaseResponse)
def get_location_by_id(location_id : int , db:Session = Depends(get_db)):
    try:
        db_location = db.get(Location, location_id)
        if not db_location:
            raise HTTPException(status_code=404, detail=f'Id "{location_id}" Cannot Be Found')
        return Location_Schema.Location_SchemaBaseResponse(status_code=200, data=db_location)
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error "{ex}" Occured')

@user.post('/', response_model=Location_Schema.Location_SchemaBaseResponse)
def add_location(location_schema : Location_Schema.Location_SchemaBase, db : Session = Depends(get_db)):
    try:
        location = Location(**location_schema.model_dump(exclude={'location_id'}))
        db.add(location)
        db.commit()
        db.refresh(location)
        return Location_Schema.Location_SchemaBaseResponse(status_code=200, data=location)
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error "{ex}" Occured')

@user.put('/', response_model=Location_Schema.Location_SchemaBaseResponse)
def update_location(location_id : int,location_schema : Location_Schema.Location_SchemaBase, db : Session = Depends(get_db)):
    try:
        query_location = Location.model_validate(location_schema)
        db_location = db.get(Location, location_id)
        if not db_location:
            raise HTTPException(status_code=404,detail=f'Id "{location_id}" Cannot Be Found')
        dump = query_location.model_dump(exclude={'location_id'}, exclude_unset=True)
        db_location.sqlmodel_update(dump)
        db.add(db_location)
        db.commit()
        db.refresh(db_location)
        return Location_Schema.Location_SchemaBaseResponse(status_code=200, data=db_location)
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error "{ex}" Occured')

@user.delete('/', response_model=Status_Response.StatusResponseBase)
def delete_location(location_id : int, db : Session = Depends(get_db)):
    try:
        db_location = db.get(Location, location_id)
        db.delete(db_location)
        db.commit()
        return Status_Response.StatusResponseBase(status_code=200, data=True)
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error {ex} Occurred')