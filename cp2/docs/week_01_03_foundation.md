# Weeks 1-3 Foundation

## Purpose

This stage establishes the Android Flutter foundation for the herewego hotel
decision-support prototype. It does not implement booking, payment, review AI,
or live provider integrations.

## Toolchain verified

- Flutter 3.29.3 on the stable channel
- Dart 3.6.0
- Android Studio 2025.3
- Android SDK 34 with Android platform 35 installed
- Android API 34 emulators configured

`flutter doctor -v` currently reports that some Android SDK licences still need
to be accepted by the developer before final Android deployment checks.

## Implemented workflow

1. The discovery screen accepts a hotel name, destination, or keyword.
2. Optional stay-quality filters can be selected.
3. The mock repository returns the top three ranked candidates.
4. The user confirms the intended hotel before hotel details are loaded.
5. The camera route attempts to start a live preview.
6. If live preview is unavailable, `image_picker` provides a system-camera or
   stored-gallery fallback.
7. A selected image produces a simulated top-three candidate list so the user
   journey can be tested before OCR and place services are connected.

## Project structure

- `lib/app`: app entry point and named routes
- `lib/core`: shared visual theme
- `lib/features/search`: hotel models, repository boundary, mock data, search UI
- `lib/features/camera`: camera preview and image-picker fallback
- `lib/features/candidates`: ranked-candidate confirmation
- `lib/features/hotel`: confirmed-hotel hand-off screen
- `test`: widget tests for the text-search flow and validation state

The separate `../backend` folder contains the FastAPI orchestration boundary,
Pydantic contracts, controlled JSON catalogue, API tests, and Postman assets.

## Android permissions

The Android manifest requests only:

- `CAMERA`, for the live camera and system-camera fallback
- `INTERNET`, for later REST/API integration

The camera is marked as optional so the gallery fallback remains available on
emulators and devices without accessible camera hardware.

Impeller is disabled in the Android manifest because the installed API 34
emulator uses an older Vulkan renderer. Flutter uses the compatible Skia
renderer automatically, so normal Android Studio Run actions work without a
special command-line flag.

## Verification commands

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

To run Flutter against the local FastAPI service on an Android emulator:

```bash
flutter run \
  --dart-define=HEREWEGO_API_MODE=remote \
  --dart-define=HEREWEGO_API_BASE_URL=http://10.0.2.2:8000
```

Mock mode remains the default when the Dart definitions are omitted. Local
cleartext HTTP is allowed only in the Android debug manifest; release builds
continue to require HTTPS.

For an API 34 emulator:

```bash
flutter emulators --launch Pixel_4_API_34
flutter run
```

## Week 3 completion evidence

- Text search field is functional.
- Filter selections affect mock ranking.
- Top-three candidate cards display name, address, rating, and confidence.
- Confirming a candidate opens the hotel hand-off screen.
- Camera and gallery controls are connected through replaceable plugin APIs.
- Automated widget tests cover the main text-search path.
