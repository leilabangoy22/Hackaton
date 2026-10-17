from fastapi import APIRouter, Depends, Query, HTTPException, status
from typing import Annotated, List
from sqlmodel import Session, select, desc
from datetime import datetime, timedelta

from ..db import get_db
from ..schemas import Flood_Sensor_Schema
from ..model import Flood_Sensor
from ..response import Status_Response
from ..dto import sensor_flood_dto


sensor = APIRouter(prefix="/Flood_Sensor", tags=["Flood Sensor"])


@sensor.get("/", response_model=Flood_Sensor_Schema.Flood_SensorBaseListResponse)
def get_all_sensor(db: Session = Depends(get_db), offset: int = 0, limit: Annotated[int, Query(le=100)] = 100):
    try:
        query_sensor = select(Flood_Sensor).offset(offset).limit(limit).order_by(desc(Flood_Sensor.data_id))
        db_sensor = db.exec(query_sensor).all()
        if not db_sensor:
            raise HTTPException(status_code=404, detail="No Flood Sensor Data Found")
        return Flood_Sensor_Schema.Flood_SensorBaseListResponse(status_id=200, data=db_sensor)
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error "{ex}" Occurred')

@sensor.get('/DataPerSecond', status_code=status.HTTP_200_OK)
def get_normal_data ():
    try:
        if not cache_list:
            raise HTTPException(status_code=404, detail="No New Data Found")
        return {
            "Status Code" : 200,
            "Data" : cache_list
        }
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error "{ex}" Occurred')

@sensor.get("/{sensor_id}", response_model=Flood_Sensor_Schema.Flood_SensorBaseResponse)
def get_sensor_sensor_by_id(sensor_id: int, db: Session = Depends(get_db)):
    try:
        db_sensor = db.get(Flood_Sensor, sensor_id)
        if not db_sensor:
            raise HTTPException(status_code=404, detail=f'Id "{sensor_id}" Cannot Be Found')
        return Flood_Sensor_Schema.Flood_SensorBaseResponse(status_id=200, data=db_sensor)
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error "{ex}" Occurred')

cache_list : List = [] # Holds The Data Temprarily
time_delta : datetime | None = None
data_list : List[int] = []

@sensor.post("/", response_model=sensor_flood_dto.Flood_SensorBaseList)
async def add_sensor_data(sensor_schema: Flood_Sensor_Schema.Flood_SensorBase, db: Session = Depends(get_db)):
    try:
        global cache_list, time_delta, data_list
        sensor_time = datetime.now()
        if time_delta is None:
            time_delta = sensor_time + timedelta(minutes=1)
        if time_delta > sensor_time:
            data_list.insert(0, sensor_schema.data)
            data_payload = sensor_flood_dto.Flood_SensorBase(
                flood_data=sensor_schema.data,
                created_at=datetime.now()
            )
            cache_list.insert(0,data_payload)
            return sensor_flood_dto.Flood_SensorBaseList(status_code=200, datas=cache_list)
        total_data = sum(data_list)
        ave_data = total_data / len(data_list)
        sensor_schema.created_at = datetime.now()
        new_sensor = Flood_Sensor(
            data=ave_data,
            created_at=sensor_time
        )
        db.add(new_sensor)
        db.commit()
        db.refresh(new_sensor)
        pyd_obj = sensor_flood_dto.Flood_SensorBase.model_validate({
        "data_id" : new_sensor.data_id,
        "flood_data": ave_data,
        "created_at": new_sensor.created_at
        })
        data_list.clear()
        cache_list.clear() # refresh data for normal data
        time_delta = None
        return sensor_flood_dto.Flood_SensorBaseList(status_code=200, data=pyd_obj)
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error "{ex}" Occurred')


@sensor.put("/", response_model=Flood_Sensor_Schema.Flood_SensorBaseResponse)
def update_sensor_sensor(sensor_id: int, sensor_schema: Flood_Sensor_Schema.Flood_SensorBase, db: Session = Depends(get_db)):
    try:
        db_sensor = db.get(Flood_Sensor, sensor_id)
        if not db_sensor:
            raise HTTPException(status_code=404, detail=f'Id "{sensor_id}" Cannot Be Found')
        sensor_data = sensor_schema.model_dump(
            exclude={"data_id"},
            exclude_unset=True
        )
        db_sensor.sqlmodel_update(sensor_data)
        db.add(db_sensor)
        db.commit()
        db.refresh(db_sensor)
        return Flood_Sensor_Schema.Flood_SensorBaseResponse(status_id=200, data=db_sensor)
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error "{ex}" Occurred')


@sensor.delete("/", response_model=Status_Response.StatusResponseBase)
def delete_sensor_sensor(sensor_id: int, db: Session = Depends(get_db)):
    try:
        db_sensor = db.get(Flood_Sensor, sensor_id)
        if not db_sensor:
            raise HTTPException(status_code=404, detail=f'Id "{sensor_id}" Cannot Be Found')
        db.delete(db_sensor)
        db.commit()
        return Status_Response.StatusResponseBase(status_code=200, data=True)
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error "{ex}" Occurred')
