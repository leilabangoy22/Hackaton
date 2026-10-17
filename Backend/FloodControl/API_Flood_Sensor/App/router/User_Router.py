from fastapi import APIRouter, Depends, Query, HTTPException, status, Request
from typing import Annotated
from sqlmodel import Session, select, func
from sqlalchemy import or_
import bcrypt
import re

from ..db import get_db
from ..schemas import User_Schema
from ..model import User, Location
from ..response import Status_Response
from ..dto import log_in_dto
from ..service import check_cred

dispatcher = APIRouter(prefix='/Dispatcher/User', tags=['User'])
user = APIRouter(prefix='/User/User', tags=['User'])
rescuer = APIRouter(prefix='/Rescuer/User', tags=['User'])

@dispatcher.get('/', response_model=User_Schema.User_Display_SchemaBaseListResponse)
def get_all_user(db: Session = Depends(get_db), offset: int = 0, limit : Annotated[int, Query(le=100)] = 100):
    try:
        query_user = select(User).offset(offset).limit(limit)
        db_user = db.exec(query_user).all()
        if not db_user:
            raise HTTPException(status_code=404, detail='No User Has Been Added')
        return User_Schema.User_Display_SchemaBaseListResponse(status_code=200, data=db_user)
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error "{ex}" Occured')

@dispatcher.get('/{user_id}', response_model=User_Schema.User_Display_SchemaBaseResponse)
def get_user_by_id(user_id : int , db:Session = Depends(get_db)):
    try:
        db_user = db.get(User, user_id)
        if not db_user:
            raise HTTPException(status_code=404, detail=f'Id "{user_id}" Cannot Be Found')
        return User_Schema.User_Display_SchemaBaseResponse(status_code=200, data=db_user)
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error "{ex}" Occured')

@user.post('/log_in', status_code=status.HTTP_200_OK)
def log_in(payload : log_in_dto.Log_InSchemaBase, request : Request,db : Session = Depends(get_db)):
    try:
        check_user = db.exec(select(User).where(or_(User.email == payload.name, User.name == payload.name))).first()
        if not check_user:
            raise HTTPException(status_code=401, detail='Invalid Credentials! Username Incorrect')
        if not bcrypt.checkpw(payload.password.encode(), check_user.password_hash.encode()):
            raise HTTPException(status_code=401, detail='Invalid Credentials! Password Incorrect')
        return {
            'status_code' : 200,
            'message' : f'Login Successful, Welcome Back {check_user.name}'
        }
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error "{ex}" Occured')

@user.post('/register', response_model=User_Schema.User_Display_SchemaBaseResponse)
def register(user_schema : User_Schema.User_SchemaBase,db : Session = Depends(get_db)):
    try:
        check_user = db.exec(select(User).where(User.email == user_schema.email)).first()
        if check_user:
            raise HTTPException(status_code=409, detail=f'Email "{user_schema.email}" Already Exist!')
        hashed_pw = bcrypt.hashpw(user_schema.password.encode(), bcrypt.gensalt()).decode()
        if re.search(r".*@Dispatcher", user_schema.email,re.IGNORECASE):
            user_schema.role = 'Dispatcher'
        elif re.search(r".*@Rescuer", user_schema.email,re.IGNORECASE):
            user_schema.role = 'Rescuer'
        else:
            user_schema.role = 'User'
        user = User(
            email = user_schema.email,
            password_hash=hashed_pw,
            name=user_schema.name,
            mobile_number=user_schema.mobile_number,
            isActive=True,
            role=user_schema.role
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        return User_Schema.User_Display_SchemaBaseResponse(status_code=200, data=user)
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error "{ex}" Occured')

@user.post('/log_out', status_code=status.HTTP_200_OK)
def log_out():
    try:
        return{
            "status_code" : 200,
            "message" : "Logged Out Successfully"
        }
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error "{ex}" Occured')

@user.put('/update_user_location/{user_id}', response_model=User_Schema.User_Display_SchemaBaseResponse)
def update_location(user_id :int, addlocation:log_in_dto.Update_LocationBase, db : Session = Depends(get_db)):
    try:
        get_user = db.get(User, user_id)
        if not get_user:
            raise HTTPException(status_code=404, detail="No User Found")
        get_location = db.get(Location , addlocation.location_id)
        if not get_location:
            raise HTTPException(status_code=404, detail="No Location Found")
        get_user.location_id = addlocation.location_id
        payload = User_Schema.User_Display_SchemaBase(
            user_id=get_user.user_id,
            name=get_user.name,
            email=get_user.email,
            mobile_number=get_user.mobile_number,
            role=get_user.role,
            location_id=addlocation.location_id
        )
        db.commit()
        db.refresh(get_user)
        return User_Schema.User_Display_SchemaBaseResponse(status_code=200,data=payload)
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error "{ex}" Occured')

@rescuer.put('/{user_id}', response_model=log_in_dto.IsActiveBaseResponse)
def isActive(isActive : log_in_dto.IsActiveBase, user_id : int,db : Session = Depends(get_db)):
    try:
        get_user = db.exec(select(User).where(User.user_id == user_id)).first()
        get_user.isActive = isActive.isActive
        status_data = "Active" if get_user.isActive is True else "Inactive"
        data = log_in_dto.IsActiveBaseSTR(isActiveSTR=status_data)
        db.commit()
        db.refresh(get_user)
        return log_in_dto.IsActiveBaseResponse(status_code=200, data=data)
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error "{ex}" Occured')


@user.put('/Change_Password', status_code=status.HTTP_200_OK)
def change_password(user_id  : int,pass_schema : log_in_dto.Change_PasswordBase,db : Session = Depends(get_db)):
    try:
        get_user = db.get(User, user_id)
        if not bcrypt.checkpw(pass_schema.old_password.encode(), get_user.password_hash.encode()):
            raise HTTPException(status_code=401,detail='Invalid Credentials! Password Incorrect')
        new_hash_password = bcrypt.hashpw(pass_schema.new_password.encode(), bcrypt.gensalt()).decode()
        get_user.password_hash = new_hash_password
        db.commit()
        db.refresh(get_user)
        return {
            "Status Code" : 200,
            "Message" : "Password Has Been Changed!"
        }
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error {ex} Occurred')

@user.put('/{user_id}', response_model=log_in_dto.User_UpdateDisplay_SchemaBaseResponse)
def update_user(user_id : int,user_schema : log_in_dto.User_UpdateDisplay_SchemaBase, db : Session = Depends(get_db)):
    try:
        db_user = db.get(User, user_id)
        if not db_user:
            raise HTTPException(status_code=404,detail=f'Id "{user_id}" Cannot Be Found')
        dump = user_schema.model_dump(exclude_unset=True)
        dump = {
            key: value
            for key, value in dump.items()
            if value not in (None, "", "string")
        }
        db_user.sqlmodel_update(dump)
        db.commit()
        db.refresh(db_user)
        return log_in_dto.User_UpdateDisplay_SchemaBaseResponse(status_code=200, data=db_user)
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error "{ex}" Occured')

@dispatcher.delete('/', response_model=Status_Response.StatusResponseBase)
def delete_user(user_id : int, db : Session = Depends(get_db)):
    try:
        db_user = db.get(User, user_id)
        db.delete(db_user)
        db.commit()
        return Status_Response.StatusResponseBase(status_code=200, data=True)
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f'An Error {ex} Occurred')