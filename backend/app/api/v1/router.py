from functools import lru_cache
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, status

from app.core.config import Settings, get_settings
from app.schemas import (
    CandidateRequest,
    CandidateSearchResponse,
    ProviderOffer,
    SearchQuery,
)
from app.services.catalog import HotelCatalog
from app.services.ranking import RankingService

router = APIRouter()


@lru_cache
def _catalog_for_path(database_path: str) -> HotelCatalog:
    return HotelCatalog(Path(database_path))


def get_catalog(
    settings: Settings = Depends(get_settings),
) -> HotelCatalog:
    if settings.data_mode == "live":
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=(
                "Live provider mode is selected, but external provider adapters "
                "are not configured. Set HEREWEGO_DATA_MODE=mock for Week 3."
            ),
        )
    return _catalog_for_path(str(settings.database_path.resolve()))


def get_ranking_service(
    catalog: HotelCatalog = Depends(get_catalog),
) -> RankingService:
    return RankingService(catalog)


@router.post(
    "/search/text",
    response_model=CandidateSearchResponse,
    summary="Rank hotels from a text query",
)
async def search_text(
    request: SearchQuery,
    settings: Settings = Depends(get_settings),
    ranking: RankingService = Depends(get_ranking_service),
) -> CandidateSearchResponse:
    candidates = ranking.search_text(
        request.query,
        set(request.required_tags),
        request.limit,
    )
    return CandidateSearchResponse(
        mode=settings.data_mode,
        request_type="text",
        ranking_version=ranking.ranking_version,
        candidates=candidates,
    )


@router.post(
    "/candidates",
    response_model=CandidateSearchResponse,
    summary="Return controlled visual-search candidates",
)
async def visual_candidates(
    request: CandidateRequest,
    settings: Settings = Depends(get_settings),
    ranking: RankingService = Depends(get_ranking_service),
) -> CandidateSearchResponse:
    candidates = ranking.rank_visual_candidates(request.visual_hints, request.limit)
    return CandidateSearchResponse(
        mode=settings.data_mode,
        request_type=request.source,
        ranking_version=ranking.ranking_version,
        candidates=candidates,
    )


@router.get(
    "/provider-offers/{hotel_id}",
    response_model=list[ProviderOffer],
    summary="Return traceable mock provider offers from SQLite",
)
async def provider_offers(
    hotel_id: str,
    catalog: HotelCatalog = Depends(get_catalog),
) -> list[ProviderOffer]:
    if catalog.find(hotel_id) is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Hotel was not found.",
        )

    return list(catalog.offers_for(hotel_id))
