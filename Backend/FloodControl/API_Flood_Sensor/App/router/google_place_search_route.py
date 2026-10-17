from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import JSONResponse
import httpx
from starlette.requests import Request  # Import Request for accessing query params
from .. import config

from ..dto import google_place_search_dto

settings = config.Settings()

# Replace with your actual API key
API_KEY = settings.map_key
GOOGLE_MAPS_DIRECTIONS_BASE_URL = "https://maps.googleapis.com/maps/api/directions/json"
GOOGLE_MAPS_BASE_URL = "https://maps.googleapis.com/maps/api/place/textsearch/json"
GOOGLE_MAPS_PLACE_ID_BASE_URL = "https://maps.googleapis.com/maps/api/place/details/json"

user = APIRouter(prefix="/maps", tags=["maps"])

@user.get('/directions')
async def get_directions(request: Request):
    """
    Retrieves driving directions from the Google Maps Directions API.

    Query parameters:
        origin (required): The starting point for the directions.
        destination (required): The destination point for the directions.

    Returns:
    
        JSON response containing the directions data or an error message.
    """
    origin = request.query_params.get('origin')
    destination = request.query_params.get('destination') 

    if not origin:
        raise HTTPException(status_code=400, detail="Missing 'origin' parameter")
    if not destination:
        raise HTTPException(status_code=400, detail="Missing 'destination' parameter")

    params = {
        'origin': origin,
        'destination': destination,
        'key': API_KEY,
        'travelmode': 'DRIVING'
    }

    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(GOOGLE_MAPS_DIRECTIONS_BASE_URL, params=params)
            response.raise_for_status()  # Raise an exception for bad status codes
            directions_data = response.json()
            return JSONResponse(status_code=200, content=directions_data)
        except httpx.HTTPError as e:
            raise HTTPException(status_code=response.status_code, detail=f"Error fetching directions: {e}")
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"An unexpected error occurred: {e}")

@user.post("/search_place")
async def search_place(search_place_query: google_place_search_dto.GooglePlaceSearchQuery):
    """
    Searches for nearby places based on a text query using the Google Places API
    and returns the results structured by the PlacesResponse Pydantic model.
    """
    search_place_query.key = API_KEY

    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(GOOGLE_MAPS_BASE_URL, params=search_place_query.model_dump())
            response.raise_for_status()  # Raise an exception for bad status codes
            data = response.json()

            list_of_search_places = []
            for place in data["results"]:
                search_place_data = {}
                search_place_data["place_id"] = place["place_id"]
                search_place_data["name"] = place["name"]
                search_place_data["latitude"] = float(place["geometry"]["location"]["lat"])
                search_place_data["longitude"] = float(place["geometry"]["location"]["lng"])
                list_of_search_places.append(search_place_data)

            return JSONResponse(status_code=200, content=list_of_search_places)
        except httpx.HTTPError as e:
            raise HTTPException(status_code=response.status_code, detail=f"Error fetching data from Google Maps API: {e}")
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"An unexpected error occurred: {e}")

@user.get("/search_place_via_place_id/")
async def search_place_via_place_id(place_id: str):
    """
    Searches for place details based on a place ID using the Google Places API
    and returns the formatted address.
    """
    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(GOOGLE_MAPS_PLACE_ID_BASE_URL, params={"place_id": place_id, "key": API_KEY})
            response.raise_for_status()  # Raise an exception for bad status codes
            data = response.json()
            return JSONResponse(status_code=200, content=data["result"]["formatted_address"])
        except httpx.HTTPError as e:
            raise HTTPException(status_code=response.status_code, detail=f"Error fetching data from Google Maps API: {e}")
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"An unexpected error occurred: {e}")