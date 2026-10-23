import geopandas as gpd
import requests
from pyproj import Transformer
from shapely.geometry import Point, box


BOUNDARY_SERVICE_URL = (
    "https://services1.arcgis.com/IwZZTMxZCmAmFYvF/"
    "ArcGIS/rest/services/City_Municipal_Boundaries/FeatureServer/0/query"
)

LAND_DATA_URL = (
    "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/"
    "master/geojson/ne_10m_land.geojson"
)

CEBU_REFERENCE_POINT = Point(123.8854, 10.3157)

SELECTED_AREAS = {"cebu", "talisay"}

CELL_SIZE_METERS = 500

PROJECTED_COORDINATE_SYSTEM = "EPSG:32651"
GEOGRAPHIC_COORDINATE_SYSTEM = "EPSG:4326"


def normalize_area_name(name):

    normalized_name = str(name).strip().casefold()

    if normalized_name.endswith(" city"):
        normalized_name = normalized_name[:-5]

    return normalized_name


def get_selected_area_boundaries():

    query_parameters = {
        "where": "REGION = 'Region VII'",
        "outFields": "*",
        "returnGeometry": "true",
        "outSR": "4326",
        "f": "geojson",
    }

    response = requests.get(
        BOUNDARY_SERVICE_URL,
        params=query_parameters,
        timeout=60,
    )
    response.raise_for_status()

    boundary_data = response.json()

    if "features" not in boundary_data:
        raise ValueError(
            "The boundary service returned an unexpected response."
        )

    if not boundary_data["features"]:
        raise ValueError(
            "The boundary service returned no administrative boundaries."
        )

    boundaries = gpd.GeoDataFrame.from_features(
        boundary_data["features"],
        crs=GEOGRAPHIC_COORDINATE_SYSTEM,
    )

    if "MUNICIPAL" not in boundaries.columns:
        raise ValueError(
            "The boundary dataset does not contain the MUNICIPAL field."
        )

    boundaries["normalized_name"] = boundaries["MUNICIPAL"].apply(
        normalize_area_name
    )

    selected = boundaries[
        boundaries["normalized_name"].isin(SELECTED_AREAS)
    ].copy()

    found_areas = set(selected["normalized_name"].unique())
    missing_areas = SELECTED_AREAS - found_areas

    if missing_areas:
        raise ValueError(
            "The following areas were not found in the boundary dataset: "
            f"{sorted(missing_areas)}."
        )

    print("Selected administrative areas:")
    print(sorted(selected["MUNICIPAL"].unique()))

    return selected


def find_cebu_island():

    land = gpd.read_file(LAND_DATA_URL)

    if land.crs is None:
        raise ValueError(
            "The land dataset does not specify a coordinate system."
        )

    land = land.to_crs(GEOGRAPHIC_COORDINATE_SYSTEM)

    for geometry in land.geometry:

        if geometry.geom_type == "MultiPolygon":
            island_parts = list(geometry.geoms)

        elif geometry.geom_type == "Polygon":
            island_parts = [geometry]

        else:
            continue

        for island_part in island_parts:

            if island_part.contains(CEBU_REFERENCE_POINT):
                return island_part

    raise ValueError(
        "Could not identify Cebu Island. Check the land dataset "
        "and the reference point."
    )


def generate_selected_area_grid(cell_size_m=CELL_SIZE_METERS):
    if cell_size_m <= 0:
        raise ValueError("The grid-cell size must be greater than zero.")

    selected_boundaries = get_selected_area_boundaries()

    study_area = selected_boundaries.geometry.union_all()

    cebu_island = find_cebu_island()

    study_area_projected = gpd.GeoSeries(
        [study_area],
        crs=GEOGRAPHIC_COORDINATE_SYSTEM,
    ).to_crs(PROJECTED_COORDINATE_SYSTEM).iloc[0]

    island_projected = gpd.GeoSeries(
        [cebu_island],
        crs=GEOGRAPHIC_COORDINATE_SYSTEM,
    ).to_crs(PROJECTED_COORDINATE_SYSTEM).iloc[0]

    study_area_projected = study_area_projected.intersection(
        island_projected
    )

    if study_area_projected.is_empty:
        raise ValueError(
            "The selected administrative areas do not overlap Cebu Island."
        )

    min_x, min_y, max_x, max_y = study_area_projected.bounds

    coordinate_transformer = Transformer.from_crs(
        PROJECTED_COORDINATE_SYSTEM,
        GEOGRAPHIC_COORDINATE_SYSTEM,
        always_xy=True,
    )

    cells = []
    row = 0
    y = min_y

    while y < max_y:

        col = 0
        x = min_x

        while x < max_x:

            square = box(
                x,
                y,
                x + cell_size_m,
                y + cell_size_m,
            )

            if square.intersects(study_area_projected):

                clipped_cell = square.intersection(
                    study_area_projected
                )

                if (
                    not clipped_cell.is_empty
                    and clipped_cell.area > 0
                ):

                    representative_point = (
                        clipped_cell.representative_point()
                    )

                    longitude, latitude = (
                        coordinate_transformer.transform(
                            representative_point.x,
                            representative_point.y,
                        )
                    )

                    cells.append(
                        {
                            "cell_id": f"{col + 1}-{row + 1}",
                            "latitude": latitude,
                            "longitude": longitude,
                            "cell_size_m": cell_size_m,
                            "land_area_m2": clipped_cell.area,
                            "geometry": clipped_cell,
                        }
                    )

            x += cell_size_m
            col += 1

        y += cell_size_m
        row += 1

    if not cells:
        raise ValueError(
            "No grid cells were generated for the selected areas."
        )

    return gpd.GeoDataFrame(
        cells,
        geometry="geometry",
        crs=PROJECTED_COORDINATE_SYSTEM,
    )


if __name__ == "__main__":

    grid = generate_selected_area_grid()

    grid_geojson = grid.to_crs(
        GEOGRAPHIC_COORDINATE_SYSTEM
    )

    output_file = "cebu_city_talisay_city_grid_xyID.geojson"

    grid_geojson.to_file(
        output_file,
        driver="GeoJSON",
    )

    print(f"Generated {len(grid)} grid cells.")
    print(f"Saved grid to {output_file}")

    print(
        grid.drop(columns="geometry").head()
    )
