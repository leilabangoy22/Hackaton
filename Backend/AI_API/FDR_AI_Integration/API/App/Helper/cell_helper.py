import geopandas as gpd
import pandas as pd
from shapely.geometry import Point
from pathlib import Path

GRID_FILE = (
    Path(__file__).resolve().parent.parent
    / "data"
    / "cebu_city_talisay_city_grid_xyID.geojson"
)

PROJECTED_CRS = "EPSG:32651"


def find_cell(latitude: float, longitude: float) -> dict | None:
    """Find the grid cell containing the user's location."""

    grid = gpd.read_file(GRID_FILE).to_crs(PROJECTED_CRS)

    user_point = gpd.GeoSeries(
        [Point(longitude, latitude)],
        crs="EPSG:4326",
    ).to_crs(PROJECTED_CRS).iloc[0]

    matching_cells = grid[grid.geometry.covers(user_point)]

    if matching_cells.empty:
        return None

    cell = matching_cells.iloc[0]
    cell_id = str(cell["cell_id"])

    column, row = cell_id.split("-")

    return {
        "cell_id": cell_id,
        "column": int(column),
        "row": int(row),
    }


def get_nearby_cells(current_cell: dict) -> list[dict]:
    grid = gpd.read_file(GRID_FILE)

    cell_ids = grid["cell_id"].astype(str).str.split("-", expand=True)

    grid["column"] = cell_ids[0].astype(int)
    grid["row"] = cell_ids[1].astype(int)

    column = current_cell["column"]
    row = current_cell["row"]

    nearby_grid = grid[
        grid["column"].between(column - 1, column + 1)
        & grid["row"].between(row - 1, row + 1)
    ]

    nearby_cells = []

    for _, cell in nearby_grid.iterrows():
        elevation = cell.get("elevation_m")

        nearby_cells.append({
            "grid_id": str(cell["cell_id"]),
            "latitude": float(cell["latitude"]),
            "longitude": float(cell["longitude"]),
            "column": int(cell["column"]),
            "row": int(cell["row"]),
            "elevation_m": (
                float(elevation)
                if pd.notna(elevation)
                else None
            ),
        })

    return nearby_cells


def assess_cells(cells: list[dict]) -> list[dict]:
    """Return cells with valid risk scores."""

    assessed_cells = []

    for cell in cells:
        risk_score = cell.get("risk_score")

        if risk_score is None:
            continue

        if not 0 <= risk_score <= 100:
            continue

        assessed_cells.append({
            "grid_id": cell["grid_id"],
            "latitude": cell["latitude"],
            "longitude": cell["longitude"],
            "risk_score": risk_score,
        })

    return assessed_cells
