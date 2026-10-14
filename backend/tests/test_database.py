import json
import sqlite3
from pathlib import Path

from app.services.catalog import HotelCatalog


DATA_DIR = Path(__file__).resolve().parents[1] / "app" / "data"
DATABASE_PATH = DATA_DIR / "herewego.db"
CLEANING_REPORT_PATH = DATA_DIR / "cleaning_report.json"


def connect() -> sqlite3.Connection:
    connection = sqlite3.connect(DATABASE_PATH)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA foreign_keys = ON")
    return connection


def test_sqlite_database_has_valid_relations_and_expected_fixture_counts() -> None:
    with connect() as connection:
        assert connection.execute("PRAGMA integrity_check").fetchone()[0] == "ok"
        assert connection.execute("PRAGMA foreign_key_check").fetchall() == []
        assert connection.execute("SELECT COUNT(*) FROM hotels").fetchone()[0] == 5
        assert (
            connection.execute("SELECT COUNT(*) FROM provider_offers").fetchone()[0]
            == 15
        )
        assert connection.execute("SELECT COUNT(*) FROM cleaning_runs").fetchone()[0] == 1


def test_stable_hotel_ids_are_unique_and_duplicate_names_are_removed() -> None:
    with connect() as connection:
        duplicate_ids = connection.execute(
            """
            SELECT hotel_id, COUNT(*) AS occurrences
            FROM hotels
            GROUP BY hotel_id
            HAVING occurrences > 1
            """
        ).fetchall()
        duplicate_names = connection.execute(
            """
            SELECT normalized_name, COUNT(*) AS occurrences
            FROM hotels
            GROUP BY normalized_name
            HAVING occurrences > 1
            """
        ).fetchall()

    assert duplicate_ids == []
    assert duplicate_names == []


def test_catalog_reads_canonical_names_aliases_and_offers_from_sqlite() -> None:
    catalog = HotelCatalog(DATABASE_PATH)

    sunway = catalog.find("sunway-resort")
    assert sunway is not None
    assert sunway.name == "Sunway Resort Hotel"
    assert "sunway resort" in sunway.search_aliases
    assert catalog.find("traders-kl").address == (
        "Kuala Lumpur City Centre, Kuala Lumpur"
    )

    offers = catalog.offers_for("sunway-resort")
    assert [offer.provider for offer in offers] == [
        "Agoda",
        "Booking.com",
        "Trip.com",
    ]
    assert offers[0].price_per_night == 420
    assert all(offer.is_mock for offer in offers)


def test_cleaning_report_records_each_removed_duplicate() -> None:
    report = json.loads(CLEANING_REPORT_PATH.read_text(encoding="utf-8"))

    assert report["hotels"]["raw_rows"] == 6
    assert report["hotels"]["canonical_rows"] == 5
    assert report["hotels"]["duplicates_removed"] == 1
    assert report["provider_offers"]["raw_rows"] == 16
    assert report["provider_offers"]["clean_rows"] == 15
    assert report["provider_offers"]["duplicates_removed"] == 1
