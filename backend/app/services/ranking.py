import re
import unicodedata
from difflib import SequenceMatcher

from app.schemas import HotelCandidate, HotelRecord
from app.services.catalog import HotelCatalog


class RankingService:
    """Deterministic Week 3 ranking that can later wrap live providers."""

    ranking_version = "week3-mock-v1"

    def __init__(self, catalog: HotelCatalog) -> None:
        self._catalog = catalog

    def search_text(
        self,
        query: str,
        required_tags: set[str],
        limit: int,
    ) -> list[HotelCandidate]:
        normalized_query = _normalize(query)
        ranked: list[HotelCandidate] = []

        for hotel in self._catalog.hotels:
            if required_tags and not required_tags.issubset(set(hotel.tags)):
                continue
            confidence = self._text_confidence(normalized_query, hotel)
            ranked.append(_to_candidate(hotel, confidence))

        ranked.sort(
            key=lambda candidate: (candidate.match_confidence, candidate.rating),
            reverse=True,
        )
        return ranked[:limit]

    def rank_visual_candidates(
        self,
        visual_hints: list[str],
        limit: int,
    ) -> list[HotelCandidate]:
        hint_text = _normalize(" ".join(visual_hints))
        visual_order = (
            ("sunway-resort", 0.92),
            ("traders-kl", 0.81),
            ("grand-hyatt-kl", 0.67),
        )
        candidates: list[HotelCandidate] = []

        for hotel_id, base_confidence in visual_order:
            hotel = self._catalog.find(hotel_id)
            if hotel is None:
                continue
            hint_bonus = 0.04 if hint_text and hint_text in _hotel_search_text(hotel) else 0
            candidates.append(
                _to_candidate(hotel, min(base_confidence + hint_bonus, 0.99))
            )

        return candidates[:limit]

    def _text_confidence(self, query: str, hotel: HotelRecord) -> float:
        name = _normalize(hotel.name)
        address = _normalize(hotel.address)
        aliases = [_normalize(alias) for alias in hotel.search_aliases]
        tags = [tag.replace("_", " ") for tag in hotel.tags]

        if query == name or query in aliases:
            return 0.99
        if name.startswith(query) or any(alias.startswith(query) for alias in aliases):
            return 0.95
        if query in name or any(query in alias for alias in aliases):
            return 0.91
        if query in address:
            return 0.84
        if any(query in tag for tag in tags):
            return 0.78

        candidate_texts = [name, address, *aliases]
        fuzzy_similarity = max(
            SequenceMatcher(None, query, candidate).ratio()
            for candidate in candidate_texts
        )
        token_overlap = _token_overlap(query, " ".join(candidate_texts))
        confidence = max(
            0.32 + (0.64 * fuzzy_similarity),
            0.45 + (0.42 * token_overlap),
        )
        return round(min(max(confidence, 0.05), 0.89), 4)


def _normalize(value: str) -> str:
    decomposed = unicodedata.normalize("NFKD", value)
    ascii_value = "".join(
        character for character in decomposed if not unicodedata.combining(character)
    )
    return re.sub(r"[^a-z0-9]+", " ", ascii_value.lower()).strip()


def _token_overlap(query: str, candidate: str) -> float:
    query_tokens = set(query.split())
    if not query_tokens:
        return 0
    return len(query_tokens.intersection(candidate.split())) / len(query_tokens)


def _hotel_search_text(hotel: HotelRecord) -> str:
    return _normalize(" ".join([hotel.name, hotel.address, *hotel.search_aliases]))


def _to_candidate(hotel: HotelRecord, confidence: float) -> HotelCandidate:
    return HotelCandidate(
        id=hotel.id,
        name=hotel.name,
        address=hotel.address,
        rating=hotel.rating,
        match_confidence=round(confidence, 4),
        tags=hotel.tags,
    )
