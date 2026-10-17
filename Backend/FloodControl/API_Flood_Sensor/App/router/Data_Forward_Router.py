import httpx 
from fastapi import APIRouter, Depends, HTTPException

module = APIRouter(prefix="/Flood_Sensor", tags=["Flood Sensor"])

CLOUD_URL = "https://cosmic-flood-api.duckdns.org/Flood_Sensor/"

@module.post("/sensor_data")
async def send_data_to_cloud(data : dict):
    try:
        print(f"Successfully Received Data From Local API: {data} \n\n")
        async with httpx.AsyncClient() as client:
            response = await client.post(CLOUD_URL, json=data)
        return {
            "status": "forwarded",
            "cloud_status": response.status_code
        }
    except Exception as ex:
        raise HTTPException(status_code=500, detail=f"Error : {ex}")