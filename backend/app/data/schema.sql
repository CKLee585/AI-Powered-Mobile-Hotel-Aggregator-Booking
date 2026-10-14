PRAGMA foreign_keys = ON;

CREATE TABLE hotels (
    hotel_id TEXT PRIMARY KEY,
    canonical_name TEXT NOT NULL,
    normalized_name TEXT NOT NULL UNIQUE,
    street_address TEXT NOT NULL,
    city TEXT NOT NULL,
    state TEXT NOT NULL,
    latitude REAL NOT NULL CHECK (latitude BETWEEN -90 AND 90),
    longitude REAL NOT NULL CHECK (longitude BETWEEN -180 AND 180),
    rating REAL NOT NULL CHECK (rating BETWEEN 0 AND 5),
    created_at TEXT NOT NULL
);

CREATE TABLE hotel_aliases (
    alias_id INTEGER PRIMARY KEY AUTOINCREMENT,
    hotel_id TEXT NOT NULL,
    alias TEXT NOT NULL,
    normalized_alias TEXT NOT NULL,
    FOREIGN KEY (hotel_id) REFERENCES hotels(hotel_id) ON DELETE CASCADE,
    UNIQUE (hotel_id, normalized_alias)
);

CREATE TABLE hotel_tags (
    hotel_id TEXT NOT NULL,
    tag TEXT NOT NULL CHECK (
        tag IN (
            'clean_rooms',
            'quiet_rooms',
            'family_friendly',
            'safety_secure',
            'non_smoking',
            'budget_friendly'
        )
    ),
    PRIMARY KEY (hotel_id, tag),
    FOREIGN KEY (hotel_id) REFERENCES hotels(hotel_id) ON DELETE CASCADE
);

CREATE TABLE provider_offers (
    offer_id TEXT PRIMARY KEY,
    hotel_id TEXT NOT NULL,
    provider TEXT NOT NULL,
    price_per_night REAL NOT NULL CHECK (price_per_night > 0),
    currency TEXT NOT NULL CHECK (
        length(currency) = 3 AND currency = upper(currency)
    ),
    fee_note TEXT NOT NULL,
    retrieved_at TEXT NOT NULL,
    external_url TEXT NOT NULL CHECK (external_url LIKE 'https://%'),
    is_mock INTEGER NOT NULL DEFAULT 1 CHECK (is_mock IN (0, 1)),
    FOREIGN KEY (hotel_id) REFERENCES hotels(hotel_id) ON DELETE CASCADE,
    UNIQUE (hotel_id, provider)
);

CREATE TABLE cleaning_runs (
    run_id INTEGER PRIMARY KEY AUTOINCREMENT,
    run_at TEXT NOT NULL,
    raw_hotel_rows INTEGER NOT NULL,
    canonical_hotel_rows INTEGER NOT NULL,
    hotel_duplicates_removed INTEGER NOT NULL,
    rejected_hotel_rows INTEGER NOT NULL,
    raw_offer_rows INTEGER NOT NULL,
    clean_offer_rows INTEGER NOT NULL,
    offer_duplicates_removed INTEGER NOT NULL
);

CREATE INDEX idx_hotels_city ON hotels(city);
CREATE INDEX idx_hotel_aliases_normalized ON hotel_aliases(normalized_alias);
CREATE INDEX idx_provider_offers_hotel ON provider_offers(hotel_id);
