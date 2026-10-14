from datetime import datetime
from enum import Enum
from typing import Literal

from pydantic import (
    AnyHttpUrl,
    BaseModel,
    ConfigDict,
    Field,
    field_validator,
)


class StrictModel(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        str_strip_whitespace=True,
        use_enum_values=True,
    )


class StayQualityFilter(str, Enum):
    CLEAN_ROOMS = "clean_rooms"
    QUIET_ROOMS = "quiet_rooms"
    FAMILY_FRIENDLY = "family_friendly"
    SAFETY_SECURE = "safety_secure"
    NON_SMOKING = "non_smoking"
    BUDGET_FRIENDLY = "budget_friendly"


class CandidateSource(str, Enum):
    CAMERA = "camera"
    GALLERY = "gallery"


class SearchQuery(StrictModel):
    query: str = Field(
        min_length=2,
        max_length=120,
        description="Hotel name, destination, landmark, or stay-quality keyword.",
        examples=["Sunwey Resort"],
    )
    required_tags: set[StayQualityFilter] = Field(default_factory=set)
    limit: int = Field(default=3, ge=1, le=10)

    @field_validator("query")
    @classmethod
    def query_must_contain_searchable_text(cls, value: str) -> str:
        if not any(character.isalnum() for character in value):
            raise ValueError("query must contain at least one letter or number")
        return value


class CandidateRequest(StrictModel):
    source: CandidateSource
    image_reference: str | None = Field(
        default=None,
        max_length=200,
        description="Safe filename or opaque reference. Do not send device paths.",
        examples=["hotel-signboard-01.jpg"],
    )
    visual_hints: list[str] = Field(default_factory=list, max_length=10)
    limit: int = Field(default=3, ge=1, le=3)

    @field_validator("image_reference")
    @classmethod
    def image_reference_must_not_be_a_device_path(
        cls, value: str | None
    ) -> str | None:
        if value is None:
            return value
        if "/" in value or "\\" in value or value in {".", ".."}:
            raise ValueError("image_reference must be a filename or opaque reference")
        return value

    @field_validator("visual_hints")
    @classmethod
    def visual_hints_must_be_short(cls, value: list[str]) -> list[str]:
        if any(len(hint) > 80 for hint in value):
            raise ValueError("each visual hint must contain at most 80 characters")
        return value


class HotelRecord(StrictModel):
    id: str = Field(pattern=r"^[a-z0-9-]+$")
    name: str = Field(min_length=2, max_length=160)
    address: str = Field(min_length=4, max_length=240)
    rating: float = Field(ge=0, le=5)
    tags: list[StayQualityFilter] = Field(default_factory=list)
    search_aliases: list[str] = Field(default_factory=list)


class HotelCandidate(StrictModel):
    id: str
    name: str
    address: str
    rating: float = Field(ge=0, le=5)
    match_confidence: float = Field(ge=0, le=1)
    tags: list[StayQualityFilter]


class CandidateSearchResponse(StrictModel):
    mode: str
    request_type: str
    ranking_version: str
    candidates: list[HotelCandidate]


class ProviderOffer(StrictModel):
    id: str
    hotel_id: str
    provider: str
    price_per_night: float = Field(gt=0)
    currency: str = Field(pattern=r"^[A-Z]{3}$")
    fee_note: str
    retrieved_at: datetime
    external_url: AnyHttpUrl
    is_mock: bool = True


class HealthResponse(StrictModel):
    status: Literal["ok"] = "ok"
    service: str
    environment: str
    data_mode: str
