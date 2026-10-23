
import math

import httpx


WEATHER_URL = "https://api.open-meteo.com/v1/forecast"
OVERPASS_URL = "https://overpass-api.de/api/interpreter"

OVERPASS_HEADERS = {
    "User-Agent": "FloodRiskAssessment/1.0",
    "Accept": "application/json",
}


def calculate_distance_km(
    latitude1: float,
    longitude1: float,
    latitude2: float,
    longitude2: float,
) -> float:
    """Calculate the approximate distance between two coordinates."""

    earth_radius_km = 6371.0

    latitude1 = math.radians(latitude1)
    latitude2 = math.radians(latitude2)

    delta_latitude = latitude2 - latitude1
    delta_longitude = math.radians(longitude2 - longitude1)

    a = (
        math.sin(delta_latitude / 2) ** 2
        + math.cos(latitude1)
        * math.cos(latitude2)
        * math.sin(delta_longitude / 2) ** 2
    )

    # Prevent floating-point rounding from making a invalid.
    a = max(0.0, min(1.0, a))

    return earth_radius_km * 2 * math.atan2(
        math.sqrt(a),
        math.sqrt(1 - a),
    )


async def get_environmental_factors(
    cells: list[dict],
) -> list[dict]:
    """Add saved elevation, current weather, and mapped lake information."""

    if not cells:
        return []

    # 1. Use elevation already saved in the GeoJSON.
    for cell in cells:
        if cell.get("elevation_m") is None:
            raise ValueError(
                f"Missing saved elevation for grid "
                f"{cell.get('grid_id', cell.get('cell_id', 'unknown'))}."
            )

    async with httpx.AsyncClient(timeout=30) as client:

        # 2. Retrieve current weather near the first cell.
        weather_response = await client.get(
            WEATHER_URL,
            params={
                "latitude": cells[0]["latitude"],
                "longitude": cells[0]["longitude"],
                "current": (
                    "temperature_2m,"
                    "relative_humidity_2m,"
                    "precipitation,"
                    "rain,"
                    "showers,"
                    "wind_speed_10m"
                ),
                "timezone": "auto",
            },
        )

        weather_response.raise_for_status()

        weather = weather_response.json().get("current")

        if not weather:
            raise ValueError(
                "Current weather data is unavailable."
            )

        # 3. Retrieve nearby mapped lakes and reservoirs.
        lake_features = []
        lake_data_status = "available"

        lake_queries = []

        for cell in cells:
            latitude = cell["latitude"]
            longitude = cell["longitude"]

            lake_queries.append(
                f'nwr(around:5000,{latitude},{longitude})'
                '["natural"="water"]["water"~"lake|reservoir"];'
            )

            lake_queries.append(
                f'nwr(around:5000,{latitude},{longitude})'
                '["landuse"="reservoir"];'
            )

        query = (
            "[out:json][timeout:25];\n"
            "(\n"
            + "\n".join(lake_queries)
            + "\n);\n"
            "out center tags;"
        )

        try:
            lake_response = await client.post(
                OVERPASS_URL,
                data={"data": query},
                headers=OVERPASS_HEADERS,
                timeout=45.0,
            )

            lake_response.raise_for_status()

            lake_features = lake_response.json().get(
                "elements",
                [],
            )

        except (httpx.HTTPError, ValueError) as error:
            # Lake data is optional.
            lake_features = []
            lake_data_status = (
                f"unavailable: {type(error).__name__}"
            )

        # 4. Attach environmental information to each cell.
        enriched_cells = []

        for cell in cells:
            lake_distances = []

            for feature in lake_features:
                center = feature.get("center", feature)

                lake_latitude = center.get("lat")
                lake_longitude = center.get("lon")

                if (
                    lake_latitude is None
                    or lake_longitude is None
                ):
                    continue

                distance = calculate_distance_km(
                    cell["latitude"],
                    cell["longitude"],
                    lake_latitude,
                    lake_longitude,
                )

                lake_distances.append(distance)

            nearest_lake_km = (
                round(min(lake_distances), 3)
                if lake_distances
                else None
            )

            enriched_cells.append({
                **cell,
                "elevation_m": cell["elevation_m"],
                "weather": weather,
                "nearest_mapped_lake_km": nearest_lake_km,
                "lake_data_status": lake_data_status,
            })

    return enriched_cells
