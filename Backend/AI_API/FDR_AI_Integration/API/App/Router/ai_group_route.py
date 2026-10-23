
import asyncio
import json
import logging

from fastapi import APIRouter, HTTPException, Query
from google import genai

# import config
from ..settings import Settings # -- Remote

from ..DTO import ai_params_dto, risk_response_dto
from ..Helper import cell_helper, environmental_helper


logger = logging.getLogger(__name__)

setting = Settings()
client = genai.Client(api_key=setting.gemini_key)

ai = APIRouter(
    prefix="/AI",
    tags=["AI Intervention"]
)

HIGH_RISK_THRESHOLD = 70.0


@ai.get("/assess-risk",response_model=ai_params_dto.AIParamsResponseDTO)
async def assess_risk(flood_height_by_feet: float, latitude: float = Query(..., ge=-90, le=90),longitude: float = Query(..., ge=-180, le=180)):
    """
    Assess nearby grid cells using environmental data and Gemini.
    """

    current_cell = cell_helper.find_cell(
        latitude=latitude,
        longitude=longitude,
    )

    if current_cell is None:
        raise HTTPException(
            status_code=404,
            detail="No grid cell contains the provided coordinates.",
        )

    nearby_cells = cell_helper.get_nearby_cells(
        current_cell=current_cell,
    )

    if not nearby_cells:
        raise HTTPException(
            status_code=404,
            detail="No nearby grid cells were found.",
        )

    current_grid_id = current_cell.get(
        "grid_id",
        current_cell.get("cell_id"),
    )

    if current_grid_id is None:
        raise HTTPException(
            status_code=500,
            detail="The current grid cell has no grid identifier.",
        )

    # Ensure the current cell is first.
    nearby_cells = sorted(
        nearby_cells,
        key=lambda cell: (
            cell.get("grid_id", cell.get("cell_id"))
            != current_grid_id
        ),
    )

    # ----- Here wee retrieve elevation, weather, and nearby lake data
    try:
        environmental_cells = (
            await environmental_helper.get_environmental_factors(
                nearby_cells
            )
        )

    except Exception as exc:
        logger.exception(
            "Environmental data retrieval failed."
        )

        raise HTTPException(
            status_code=502,
            detail=(
                "Environmental data error: "
                f"{type(exc).__name__}: {exc}"
            ),
        ) from exc

    if not environmental_cells:
        raise HTTPException(
            status_code=422,
            detail="No environmental data was available.",
        )

    # 4. Prompt Gemini.
    prompt = f"""
RISK SCORING:

Assign each grid cell a preliminary flood-risk score
from 0 to 100.

Use these score ranges as interpretation guidance:
- 0–19: Low estimated risk based on available data
- 20–39: Elevated factors are limited, but uncertainty remains
- 40–59: Some concerning factors or significant uncertainty
- 60–79: Multiple concerning indicators
- 80–100: Strong indicators of potential flood risk

Consider the following evidence separately:

Guidelines:
- Lower elevation may increase susceptibility, but is not
  enough by itself to establish high flood risk.
- Consider rainfall and precipitation, but zero current
  rainfall does not rule out flooding.
- Lake proximity is contextual; it does not prove a
  connection to rivers or drainage.
- Treat missing data as unknown, never as zero.
- Do not invent data or guarantee any area is safe.
- Scores are preliminary estimates, not probabilities.
Do not claim these scores are measured probabilities.
Do not guarantee that any location is safe.
Assess every supplied grid cell exactly once.
USER-REPORTED FLOODWATER HEIGHT:

{flood_height_by_feet} feet

Treat this as a user-reported observation at the
requested location, not a measurement for every nearby cell.
Use it as evidence of current flooding, specially if the user has 
higher elevation than the area


ENVIRONMENTAL DATA:

{json.dumps(environmental_cells, indent=2)}
"""

    # 5. Ask Gemini to generate the risk assessments.
    try:
        response = await asyncio.to_thread(
            client.models.generate_content,
            model="gemini-3.5-flash",
            contents=prompt,
            config={
                "response_mime_type": "application/json",
                "response_schema": (
                    risk_response_dto.GeminiRiskResponse
                ),
            },
        )

        if not response.text:
            raise ValueError(
                "Gemini returned an empty response."
            )

        gemini_result = (
            risk_response_dto.GeminiRiskResponse
            .model_validate_json(response.text)
        )

    except Exception as exc:
        logger.exception(
            "Gemini flood-risk assessment failed."
        )

        raise HTTPException(
            status_code=502,
            detail=(
                "Gemini assessment error: "
                f"{type(exc).__name__}: {exc}"
            ),
        ) from exc

    #  Match the Gemini assessments to the actual grid cells
    scores_by_id = {}

    for assessment in gemini_result.assessments:

        if assessment.grid_id in scores_by_id:
            raise HTTPException(
                status_code=502,
                detail=(
                    "Gemini returned duplicate grid assessments."
                ),
            )

        scores_by_id[assessment.grid_id] = assessment

    # Get the actual grid ID from the environmental data
    expected_ids = {
        cell.get("grid_id", cell.get("cell_id"))
        for cell in environmental_cells
    }

    if None in expected_ids:
        raise HTTPException(
            status_code=500,
            detail=(
                "Environmental data contains a cell "
                "without a grid identifier."
            ),
        )

    # sure Gemini assessed every grid cell
    if set(scores_by_id) != expected_ids:
        raise HTTPException(
            status_code=502,
            detail=(
                "Gemini did not return exactly one "
                "assessment for every grid cell."
            ),
        )

    # Combine environmental information and Gemini scores
    assessed_cells = []

    for cell in environmental_cells:

        grid_id = cell.get(
            "grid_id",
            cell.get("cell_id"),
        )

        assessment = scores_by_id[grid_id]

        assessed_cells.append({
            **cell,
            "grid_id": grid_id,
            "risk_score": assessment.risk_score,
            "risk_reason": assessment.risk_reason,
        })

    # Validate risk scores
    valid_cells = [
        cell
        for cell in assessed_cells
        if cell.get("risk_score") is not None
        and 0 <= cell["risk_score"] <= 100
    ]

    if not valid_cells:
        raise HTTPException(
            status_code=422,
            detail="No valid risk scores are available.",
        )

    # here for identify high-risk areas 
    high_risk_areas = sorted(
        [
            cell
            for cell in valid_cells
            if cell["risk_score"] >= HIGH_RISK_THRESHOLD
        ],
        key=lambda cell: cell["risk_score"],
        reverse=True,
    )

    # identify the lowest-scoring area
    safest_area = min(
        valid_cells,
        key=lambda cell: cell["risk_score"],
    )

    return ai_params_dto.AIParamsResponseDTO(
        high_risk_areas=high_risk_areas,
        safest_area=safest_area,
        ai_assessment=gemini_result.ai_assessment,
    )
