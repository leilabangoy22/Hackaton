
import asyncio
import httpx
import geopandas as gpd

from Helper.cell_helper import GRID_FILE

ELEVATION_URL = "https://api.open-meteo.com/v1/elevation"
BATCH_SIZE = 100


async def main():
    grid = gpd.read_file(GRID_FILE)

    # Reuse elevations if the script is run again.
    if "elevation_m" not in grid.columns:
        grid["elevation_m"] = float("nan")

    missing = grid["elevation_m"].isna()
    missing_indices = grid.index[missing].tolist()

    if not missing_indices:
        print("All grid cells already have elevations.")
        return

    print(f"Grid cells needing elevation: {len(missing_indices)}")

    async with httpx.AsyncClient(timeout=60) as client:
        for start in range(0, len(missing_indices), BATCH_SIZE):
            batch_indices = missing_indices[start:start + BATCH_SIZE]
            batch = grid.loc[batch_indices]

            params = {
                "latitude": ",".join(map(str, batch["latitude"])),
                "longitude": ",".join(map(str, batch["longitude"])),
            }

            for attempt in range(4):
                response = await client.get(
                    ELEVATION_URL,
                    params=params,
                )

                if response.status_code == 429:
                    delay = 10 * (attempt + 1)
                    print(f"Rate limited. Waiting {delay} seconds...")
                    await asyncio.sleep(delay)
                    continue

                response.raise_for_status()
                elevations = response.json().get("elevation")

                if not isinstance(elevations, list):
                    raise ValueError("Invalid elevation response.")

                if len(elevations) != len(batch_indices):
                    raise ValueError("Elevation count does not match batch.")

                grid.loc[batch_indices, "elevation_m"] = elevations
                print(
                    f"Saved elevations for "
                    f"{min(start + BATCH_SIZE, len(missing_indices))}"
                    f"/{len(missing_indices)} cells"
                )
                break
            else:
                raise RuntimeError(
                    "Elevation API kept returning 429. "
                    "Wait before running the script again."
                )

            # Avoid sending requests too quickly.
            await asyncio.sleep(2)

    # Save to a temporary file first, so the original is not
    # overwritten until all batches have succeeded.
    if grid["elevation_m"].isna().any():
        raise ValueError("Some cells still have missing elevations.")

    grid.to_file(GRID_FILE, driver="GeoJSON")
    print(f"Finished! Updated GeoJSON: {GRID_FILE}")


if __name__ == "__main__":
    asyncio.run(main())
