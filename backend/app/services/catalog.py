import sqlite3
from contextlib import contextmanager
from pathlib import Path
from typing import Iterator

from app.schemas import HotelRecord, ProviderOffer


class HotelCatalog:
    """Reads reproducible Week 2 hotel fixtures from SQLite."""

    def __init__(self, database_path: Path | None = None) -> None:
        self._database_path = database_path or (
            Path(__file__).resolve().parents[1] / "data" / "herewego.db"
        )
        if not self._database_path.is_file():
            raise FileNotFoundError(
                f"Hotel database not found at {self._database_path}. "
                "Run scripts/prepare_dataset.py first."
            )
        self._hotels = self._load_hotels()

    @property
    def hotels(self) -> tuple[HotelRecord, ...]:
        return self._hotels

    def find(self, hotel_id: str) -> HotelRecord | None:
        return next((hotel for hotel in self._hotels if hotel.id == hotel_id), None)

    def offers_for(self, hotel_id: str) -> tuple[ProviderOffer, ...]:
        with self._connect() as connection:
            rows = connection.execute(
                """
                SELECT offer_id, hotel_id, provider, price_per_night, currency,
                       fee_note, retrieved_at, external_url, is_mock
                FROM provider_offers
                WHERE hotel_id = ?
                ORDER BY price_per_night ASC, provider ASC
                """,
                (hotel_id,),
            ).fetchall()

        return tuple(
            ProviderOffer(
                id=row["offer_id"],
                hotel_id=row["hotel_id"],
                provider=row["provider"],
                price_per_night=row["price_per_night"],
                currency=row["currency"],
                fee_note=row["fee_note"],
                retrieved_at=row["retrieved_at"],
                external_url=row["external_url"],
                is_mock=bool(row["is_mock"]),
            )
            for row in rows
        )

    def _load_hotels(self) -> tuple[HotelRecord, ...]:
        with self._connect() as connection:
            hotel_rows = connection.execute(
                """
                SELECT hotel_id, canonical_name, street_address, city, state,
                       rating
                FROM hotels
                ORDER BY canonical_name ASC
                """
            ).fetchall()
            alias_rows = connection.execute(
                """
                SELECT hotel_id, normalized_alias
                FROM hotel_aliases
                ORDER BY hotel_id, normalized_alias
                """
            ).fetchall()
            tag_rows = connection.execute(
                """
                SELECT hotel_id, tag
                FROM hotel_tags
                ORDER BY hotel_id, tag
                """
            ).fetchall()

        aliases: dict[str, list[str]] = {}
        for row in alias_rows:
            aliases.setdefault(row["hotel_id"], []).append(row["normalized_alias"])

        tags: dict[str, list[str]] = {}
        for row in tag_rows:
            tags.setdefault(row["hotel_id"], []).append(row["tag"])

        return tuple(
            HotelRecord(
                id=row["hotel_id"],
                name=row["canonical_name"],
                address=_join_address(
                    row["street_address"],
                    row["city"],
                    row["state"],
                ),
                rating=row["rating"],
                tags=tags.get(row["hotel_id"], []),
                search_aliases=aliases.get(row["hotel_id"], []),
            )
            for row in hotel_rows
        )

    @contextmanager
    def _connect(self) -> Iterator[sqlite3.Connection]:
        connection = sqlite3.connect(self._database_path)
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA foreign_keys = ON")
        connection.execute("PRAGMA query_only = ON")
        try:
            yield connection
        finally:
            connection.close()


def _join_address(*parts: str) -> str:
    unique_parts: list[str] = []
    seen: set[str] = set()
    for part in parts:
        key = part.strip().casefold()
        if key and key not in seen:
            unique_parts.append(part.strip())
            seen.add(key)
    return ", ".join(unique_parts)
