# herewego CP2 Prototype

Android Flutter prototype for an AI-powered hotel aggregator and
decision-support tool. The app helps a user identify a hotel, confirm ranked
candidates, and later compare provider and review evidence before leaving for
an external booking platform.

The current implementation is the Weeks 1-3 foundation. See
[`docs/week_01_03_foundation.md`](docs/week_01_03_foundation.md) for the
implemented workflow, project structure, permissions, and verification steps.

## Getting Started

Offline mock mode:

```bash
flutter run
```

FastAPI mode on an Android emulator:

```bash
flutter run \
  --dart-define=HEREWEGO_API_MODE=remote \
  --dart-define=HEREWEGO_API_BASE_URL=http://10.0.2.2:8000
```

Start the API first by following
[`../backend/README.md`](../backend/README.md). Third-party credentials remain
on the backend and are never compiled into the Android application.
