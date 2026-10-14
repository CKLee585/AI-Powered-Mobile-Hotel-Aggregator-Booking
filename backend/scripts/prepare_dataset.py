"""Clean the Week 2 fixtures and build the herewego SQLite catalogue."""

from __future__ import annotations

import json
import os
import re
import sqlite3
import unicodedata
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import pandas as pd


BACKEND_ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = BACKEND_ROOT / "app" / "data"
RAW_DIR = DATA_DIR / "raw"
HOTEL_SOURCE = RAW_DIR / "hotels_raw.csv"
OFFER_SOURCE = RAW_DIR / "provider_offers_raw.csv"
SCHEMA_PATH = DATA_DIR / "schema.sql"
DATABASE_PATH = DATA_DIR / "herewego.db"
JSON_FIXTURE_PATH = DATA_DIR / "hotels.json"
CLEANING_REPORT_PATH = DATA_DIR / "cleaning_report.json"

VALID_TAGS = {
    "clean_rooms",
    "quiet_rooms",
    "family_friendly",
    "safety_secure",
    "non_smoking",
    "budget_friendly",
}
HOTEL_ID_PATTERN = re.compile(r"^[a-z0-9-]+$")


def normalize_text(value: object) -> str:
    """Return the same comparison form used by the search-ranking layer."""

    decomposed = unicodedata.normalize("NFKD", str(value))
    ascii_value = "".join(
        character
        for character in decomposed
        if not unicodedata.combining(character)
    )
    return re.sub(r"[^a-z0-9]+", " ", ascii_value.lower()).strip()


def clean_display_text(value: object) -> str:
    text = re.sub(r"\s+", " ", str(value)).strip()
    if text.isupper() or text.islower():
        return text.title()
    return text


def split_values(value: object) -> list[str]:
    return [part.strip() for part in str(value).split("|") if part.strip()]


def join_address(*parts: str) -> str:
    unique_parts: list[str] = []
    seen: set[str] = set()
    for part in parts:
        key = normalize_text(part)
        if key and key not in seen:
            unique_parts.append(part)
            seen.add(key)
    return ", ".join(unique_parts)


def prepare_hotels(
    source: pd.DataFrame,
) -> tuple[list[dict[str, Any]], list[dict[str, str]], list[dict[str, str]], int]:
    required_columns = [
        "hotel_id",
        "name",
        "street_address",
        "city",
        "state",
        "latitude",
        "longitude",
        "rating",
    ]
    working = source.copy()
    for column in working.columns:
        working[column] = working[column].astype(str).str.strip()

    required_present = working[required_columns].ne("").all(axis=1)
    working["latitude"] = pd.to_numeric(working["latitude"], errors="coerce")
    working["longitude"] = pd.to_numeric(working["longitude"], errors="coerce")
    working["rating"] = pd.to_numeric(working["rating"], errors="coerce")
    valid_numeric = (
        working["latitude"].between(-90, 90)
        & working["longitude"].between(-180, 180)
        & working["rating"].between(0, 5)
    )
    valid_ids = working["hotel_id"].map(
        lambda value: bool(HOTEL_ID_PATTERN.fullmatch(value))
    )
    valid = working[required_present & valid_numeric & valid_ids].copy()
    rejected_rows = len(source) - len(valid)

    hotels: list[dict[str, Any]] = []
    aliases: list[dict[str, str]] = []
    tags: list[dict[str, str]] = []
    seen_fingerprints: set[tuple[str, str]] = set()

    for hotel_id, group in valid.groupby("hotel_id", sort=True):
        selected = max(
            group.to_dict(orient="records"),
            key=lambda row: (
                "hotel" in normalize_text(row["name"])
                or "resort" in normalize_text(row["name"]),
                len(row["name"]),
            ),
        )
        canonical_name = clean_display_text(selected["name"])
        street_address = clean_display_text(selected["street_address"])
        city = clean_display_text(selected["city"])
        state = clean_display_text(selected["state"])
        fingerprint = (normalize_text(canonical_name), normalize_text(street_address))
        if fingerprint in seen_fingerprints:
            rejected_rows += len(group)
            continue
        seen_fingerprints.add(fingerprint)

        hotels.append(
            {
                "hotel_id": hotel_id,
                "canonical_name": canonical_name,
                "normalized_name": normalize_text(canonical_name),
                "street_address": street_address,
                "city": city,
                "state": state,
                "latitude": float(selected["latitude"]),
                "longitude": float(selected["longitude"]),
                "rating": float(selected["rating"]),
            }
        )

        alias_by_normalized_value: dict[str, str] = {}
        for row in group.to_dict(orient="records"):
            candidates = [row["name"], *split_values(row.get("aliases", ""))]
            for candidate in candidates:
                normalized_alias = normalize_text(candidate)
                if not normalized_alias or normalized_alias == normalize_text(
                    canonical_name
                ):
                    continue
                alias_by_normalized_value.setdefault(
                    normalized_alias,
                    clean_display_text(candidate),
                )

        aliases.extend(
            {
                "hotel_id": hotel_id,
                "alias": alias_by_normalized_value[normalized_alias],
                "normalized_alias": normalized_alias,
            }
            for normalized_alias in sorted(alias_by_normalized_value)
        )

        hotel_tags = {
            tag
            for raw_tags in group["tags"]
            for tag in split_values(raw_tags)
            if tag in VALID_TAGS
        }
        tags.extend(
            {"hotel_id": hotel_id, "tag": tag}
            for tag in sorted(hotel_tags)
        )

    return hotels, aliases, tags, rejected_rows


def prepare_offers(
    source: pd.DataFrame,
    hotel_ids: set[str],
) -> tuple[list[dict[str, Any]], int, int]:
    working = source.copy()
    for column in working.columns:
        working[column] = working[column].astype(str).str.strip()

    working["price_per_night"] = pd.to_numeric(
        working["price_per_night"], errors="coerce"
    )
    working["retrieved_at"] = pd.to_datetime(
        working["retrieved_at"], errors="coerce", utc=True
    )
    working["is_mock"] = pd.to_numeric(working["is_mock"], errors="coerce")

    valid = working[
        working["hotel_id"].isin(hotel_ids)
        & working["offer_id"].ne("")
        & working["provider"].ne("")
        & working["price_per_night"].gt(0)
        & working["currency"].str.fullmatch(r"[A-Z]{3}", na=False)
        & working["retrieved_at"].notna()
        & working["external_url"].str.startswith("https://")
        & working["is_mock"].isin([0, 1])
    ].copy()
    rejected_rows = len(source) - len(valid)

    valid.sort_values("retrieved_at", ascending=False, inplace=True)
    deduplicated = valid.drop_duplicates(
        subset=["hotel_id", "provider"], keep="first"
    ).copy()
    duplicate_rows = len(valid) - len(deduplicated)
    deduplicated.sort_values(
        ["hotel_id", "price_per_night", "provider"], inplace=True
    )

    offers = [
        {
            "offer_id": row.offer_id,
            "hotel_id": row.hotel_id,
            "provider": row.provider,
            "price_per_night": float(row.price_per_night),
            "currency": row.currency,
            "fee_note": row.fee_note,
            "retrieved_at": row.retrieved_at.isoformat(),
            "external_url": row.external_url,
            "is_mock": int(row.is_mock),
        }
        for row in deduplicated.itertuples(index=False)
    ]
    return offers, rejected_rows, duplicate_rows


def build_database(
    hotels: list[dict[str, Any]],
    aliases: list[dict[str, str]],
    tags: list[dict[str, str]],
    offers: list[dict[str, Any]],
    report: dict[str, Any],
) -> None:
    temporary_path = DATABASE_PATH.with_suffix(".db.tmp")
    temporary_path.unlink(missing_ok=True)
    connection = sqlite3.connect(temporary_path)
    try:
        connection.execute("PRAGMA foreign_keys = ON")
        connection.executescript(SCHEMA_PATH.read_text(encoding="utf-8"))
        with connection:
            connection.executemany(
                """
                INSERT INTO hotels (
                    hotel_id, canonical_name, normalized_name, street_address,
                    city, state, latitude, longitude, rating, created_at
                ) VALUES (
                    :hotel_id, :canonical_name, :normalized_name, :street_address,
                    :city, :state, :latitude, :longitude, :rating, :created_at
                )
                """,
                [
                    {**hotel, "created_at": report["run_at"]}
                    for hotel in hotels
                ],
            )
            connection.executemany(
                """
                INSERT INTO hotel_aliases (hotel_id, alias, normalized_alias)
                VALUES (:hotel_id, :alias, :normalized_alias)
                """,
                aliases,
            )
            connection.executemany(
                """
                INSERT INTO hotel_tags (hotel_id, tag)
                VALUES (:hotel_id, :tag)
                """,
                tags,
            )
            connection.executemany(
                """
                INSERT INTO provider_offers (
                    offer_id, hotel_id, provider, price_per_night, currency,
                    fee_note, retrieved_at, external_url, is_mock
                ) VALUES (
                    :offer_id, :hotel_id, :provider, :price_per_night, :currency,
                    :fee_note, :retrieved_at, :external_url, :is_mock
                )
                """,
                offers,
            )
            connection.execute(
                """
                INSERT INTO cleaning_runs (
                    run_at, raw_hotel_rows, canonical_hotel_rows,
                    hotel_duplicates_removed, rejected_hotel_rows,
                    raw_offer_rows, clean_offer_rows, offer_duplicates_removed
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    report["run_at"],
                    report["hotels"]["raw_rows"],
                    report["hotels"]["canonical_rows"],
                    report["hotels"]["duplicates_removed"],
                    report["hotels"]["rejected_rows"],
                    report["provider_offers"]["raw_rows"],
                    report["provider_offers"]["clean_rows"],
                    report["provider_offers"]["duplicates_removed"],
                ),
            )

        integrity_result = connection.execute("PRAGMA integrity_check").fetchone()[0]
        foreign_key_errors = connection.execute("PRAGMA foreign_key_check").fetchall()
        if integrity_result != "ok" or foreign_key_errors:
            raise RuntimeError(
                "SQLite verification failed: "
                f"integrity={integrity_result}, foreign_keys={foreign_key_errors}"
            )
    except Exception:
        connection.close()
        temporary_path.unlink(missing_ok=True)
        raise
    else:
        connection.close()
        os.replace(temporary_path, DATABASE_PATH)


def write_json_fixture(
    hotels: list[dict[str, Any]],
    aliases: list[dict[str, str]],
    tags: list[dict[str, str]],
) -> None:
    aliases_by_hotel: dict[str, list[str]] = {}
    for alias in aliases:
        aliases_by_hotel.setdefault(alias["hotel_id"], []).append(
            alias["normalized_alias"]
        )

    tags_by_hotel: dict[str, list[str]] = {}
    for tag in tags:
        tags_by_hotel.setdefault(tag["hotel_id"], []).append(tag["tag"])

    payload = [
        {
            "id": hotel["hotel_id"],
            "name": hotel["canonical_name"],
            "address": join_address(
                hotel["street_address"], hotel["city"], hotel["state"]
            ),
            "rating": hotel["rating"],
            "tags": tags_by_hotel.get(hotel["hotel_id"], []),
            "search_aliases": aliases_by_hotel.get(hotel["hotel_id"], []),
        }
        for hotel in sorted(hotels, key=lambda item: item["canonical_name"])
    ]
    JSON_FIXTURE_PATH.write_text(
        json.dumps(payload, indent=2) + "\n",
        encoding="utf-8",
    )


def main() -> None:
    hotel_source = pd.read_csv(HOTEL_SOURCE, dtype=str, keep_default_na=False)
    offer_source = pd.read_csv(OFFER_SOURCE, dtype=str, keep_default_na=False)

    hotels, aliases, tags, rejected_hotels = prepare_hotels(hotel_source)
    offers, rejected_offers, duplicate_offers = prepare_offers(
        offer_source,
        {hotel["hotel_id"] for hotel in hotels},
    )
    run_at = datetime.now(timezone.utc).isoformat()
    report = {
        "run_at": run_at,
        "sources": {
            "hotels": str(HOTEL_SOURCE.relative_to(BACKEND_ROOT)),
            "provider_offers": str(OFFER_SOURCE.relative_to(BACKEND_ROOT)),
        },
        "hotels": {
            "raw_rows": len(hotel_source),
            "canonical_rows": len(hotels),
            "duplicates_removed": len(hotel_source) - rejected_hotels - len(hotels),
            "rejected_rows": rejected_hotels,
            "aliases_created": len(aliases),
            "tags_created": len(tags),
        },
        "provider_offers": {
            "raw_rows": len(offer_source),
            "clean_rows": len(offers),
            "duplicates_removed": duplicate_offers,
            "rejected_rows": rejected_offers,
        },
    }

    build_database(hotels, aliases, tags, offers, report)
    write_json_fixture(hotels, aliases, tags)
    CLEANING_REPORT_PATH.write_text(
        json.dumps(report, indent=2) + "\n",
        encoding="utf-8",
    )

    print(
        "Prepared "
        f"{len(hotels)} hotels, {len(aliases)} aliases, {len(tags)} tags, "
        f"and {len(offers)} provider offers in {DATABASE_PATH}."
    )
    print(
        "Removed "
        f"{report['hotels']['duplicates_removed']} duplicate hotel row and "
        f"{report['provider_offers']['duplicates_removed']} duplicate offer row."
    )


if __name__ == "__main__":
    main()
