# Release Preflight

## Current Status
- Startup is split across `main.dart`, `src/bootstrap/app_bootstrap.dart`, and `src/bootstrap/app_composition.dart`.
- Bundled schedule data remains the baseline and remote schedule sync is post-render only.
- `flutter --no-version-check analyze` passes.
- Automated tests cover startup, schedule repository flow, bloc behavior, and responsive rail panel widgets.

## Android
- `android/app/src/main/AndroidManifest.xml` disables cleartext traffic and backup.
- Release signing falls back to debug signing when `android/key.properties` is absent.
- `android/app/upload-keystore.jks` exists in repo, but release signing still depends on external `key.properties`.
- App Check mobile activation now uses debug providers only in debug builds and integrity providers in non-debug builds.

## iOS
- `ios/Runner/Info.plist` includes display name, launch screen, and portrait/landscape support.
- Windows cannot produce an iOS build sanity run from this workspace.
- App Check mobile activation now uses debug providers only in debug builds and App Attest or DeviceCheck fallback in non-debug builds.

## Firebase and Runtime
- Required runtime env keys:
  - `FIREBASE_PROJECT_ID`
  - `FIREBASE_API_KEY`
- Optional runtime env keys:
  - `FIREBASE_ENABLED`
  - `FIREBASE_APPCHECK_ENABLED`
  - `FIREBASE_APPCHECK_WEB_KEY`
  - `FIREBASE_MEASUREMENT_ID`
- `google-services.json` and `GoogleService-Info.plist` are not present in the repo.
- Current bootstrap relies on env-driven `FirebaseOptions`, but mobile release validation should confirm whether each Firebase product in use still requires native config files for the chosen distribution setup.

## Store Readiness Follow-Up
- Verify production App Check setup and console-side provider registration before publishing.
- Add or validate `android/key.properties` for signed release builds.
- Confirm privacy policy and terms endpoints are live at the configured website base URL.
- Run an iOS build sanity check on macOS before App Store submission.
