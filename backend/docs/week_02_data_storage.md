# Week 2: Data Storage and Dataset Preparation

## Purpose

The Week 2 data layer provides a small, controlled and reproducible catalogue
for developing the herewego search, candidate-ranking and provider-comparison
flows. It does not claim to contain live hotel availability or prices. Every
provider row is marked as mock data and remains suitable only for prototype
development and testing.

## Source-to-output process

1. `app/data/raw/hotels_raw.csv` contains hotel names, aliases, addresses,
   coordinates, ratings and stay-quality tags. It intentionally includes two
   differently formatted Sunway Resort rows to exercise duplicate handling.
2. `app/data/raw/provider_offers_raw.csv` contains mock Agoda, Booking.com and
   Trip.com offers. It intentionally includes an older duplicate Agoda row.
3. `scripts/prepare_dataset.py` uses Pandas to trim whitespace, standardize
   display casing, normalize matching text, validate coordinates and ratings,
   merge repeated hotel IDs, remove repeated provider rows and reject invalid
   records.
4. The script writes the normalized relations to `app/data/herewego.db`,
   regenerates `app/data/hotels.json` from the same cleaned records and records
   row counts in `app/data/cleaning_report.json` and the `cleaning_runs` table.
5. The script runs SQLite integrity and foreign-key checks before replacing the
   previous database. A failed preparation therefore does not overwrite the
   last valid fixture.

## Rebuild the dataset

From `CP2/backend`:

```bash
source .venv/bin/activate
python -m pip install -e '.[dev]'
python scripts/prepare_dataset.py
pytest
```

The preparation command is repeatable. Each run rebuilds the database from the
two raw CSV files instead of modifying old rows in place.

## Inspect with DB Browser for SQLite

1. Open DB Browser for SQLite.
2. Choose **Open Database** and select `app/data/herewego.db`.
3. Use **Database Structure** to inspect the primary keys, foreign keys, unique
   constraints and indexes.
4. Use **Browse Data** to inspect `hotels`, `hotel_aliases`, `hotel_tags`,
   `provider_offers` and `cleaning_runs`.
5. Use **Execute SQL** for the checks below. Inspection should be read-only;
   corrections belong in the raw CSV files and must be applied by rerunning the
   preparation script.

```sql
PRAGMA integrity_check;
PRAGMA foreign_key_check;

SELECT hotel_id, canonical_name, latitude, longitude
FROM hotels
ORDER BY canonical_name;

SELECT hotel_id, normalized_name, COUNT(*) AS occurrences
FROM hotels
GROUP BY hotel_id, normalized_name
HAVING occurrences > 1;

SELECT h.hotel_id, h.canonical_name, COUNT(o.offer_id) AS offer_count
FROM hotels AS h
LEFT JOIN provider_offers AS o ON o.hotel_id = h.hotel_id
GROUP BY h.hotel_id, h.canonical_name
ORDER BY h.canonical_name;
```

The expected results are `ok` for `integrity_check`, no rows for
`foreign_key_check`, no duplicate rows, five canonical hotels and three mock
provider offers for each hotel.

## Table responsibilities

- `hotels` stores one canonical record per stable `hotel_id`, including address
  fields and coordinates.
- `hotel_aliases` stores alternate search names linked to a hotel by foreign
  key, which allows spelling and naming variants without duplicating a hotel.
- `hotel_tags` stores the supported stay-quality filters as constrained values.
- `provider_offers` stores mock prices, fee notes, source links and retrieval
  timestamps, with one current row per hotel and provider.
- `cleaning_runs` preserves the latest cleaning counts as preparation evidence.
