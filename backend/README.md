# herewego Backend: Weeks 1-3

This FastAPI service is the credential-safe boundary between the Flutter app
and future third-party services. The Week 3 implementation uses deterministic
mock data so search, ranking, validation, and error handling can be tested
without live API keys.

The Week 2 catalogue is stored in `app/data/herewego.db`. It is generated from
controlled CSV fixtures by a Pandas cleaning script, rather than edited inside
the API route. See `docs/week_02_data_storage.md` for the complete preparation
and DB Browser inspection process.

## Implemented routes

- `GET /health`: confirms service and data-mode status.
- `POST /api/v1/search/text`: validates a query, applies stay-quality filters,
  tolerates minor spelling mistakes, and returns ranked hotel candidates.
- `POST /api/v1/candidates`: returns controlled top-three visual candidates for
  camera and gallery workflow testing.
- `GET /api/v1/provider-offers/{hotel_id}`: returns the strict `ProviderOffer`
  contract using clearly marked mock rows from SQLite.
- `GET /docs`: FastAPI Swagger UI in development and test environments.

## Local setup

The machine has Python 3.13 at `/opt/anaconda3/bin/python3.13`, which satisfies
the project's Python 3.10 or newer requirement.

```bash
cd "/Users/leechunkit/Desktop/Codex AI Skill/CP2/backend"
/opt/anaconda3/bin/python3.13 -m venv .venv
source .venv/bin/activate
python -m pip install -e '.[dev]'
python scripts/prepare_dataset.py
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Open Swagger UI at `http://127.0.0.1:8000/docs`. The Android emulator reaches
the same server through `http://10.0.2.2:8000`.

## Flutter connection modes

Offline mock mode remains the default:

```bash
flutter run
```

Use the FastAPI service from an Android emulator:

```bash
flutter run \
  --dart-define=HEREWEGO_API_MODE=remote \
  --dart-define=HEREWEGO_API_BASE_URL=http://10.0.2.2:8000
```

Use `http://127.0.0.1:8000` instead when running the Flutter macOS or web
target locally.

## Mock and live boundaries

`HEREWEGO_DATA_MODE=mock` loads the controlled SQLite catalogue. Setting it to
`live` deliberately returns HTTP 503 until an authorized provider adapter and
server-side credentials are configured. This avoids silently exposing keys or
presenting fixture data as live provider data.

Secrets belong in a local `.env` file based on `.env.example`, or in a managed
secret store. The `.env` file is ignored by Git. API responses, Swagger, and
Flutter models never include third-party credentials.

## Reproducible Week 2 data preparation

Run `python scripts/prepare_dataset.py` after changing either raw CSV file. The
script standardizes text, merges repeated hotel IDs, removes repeated provider
rows, validates numeric and URL fields, writes SQLite and JSON outputs, and
records its counts in `app/data/cleaning_report.json`. Do not manually correct
the generated database; update the raw fixture and rerun the script instead.

## Postman and tests

Import `postman/herewego_Weeks_1_3.postman_collection.json` and
`postman/herewego_Local.postman_environment.json` into Postman.

Run the automated API checks with:

```bash
pytest
```
