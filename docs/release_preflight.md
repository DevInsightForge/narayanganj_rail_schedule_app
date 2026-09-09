# Release Preflight

## Current Status
- Startup is split across `main.dart`, `src/bootstrap/app_bootstrap.dart`, and `src/bootstrap/app_composition.dart`.
- Bundled schedule data is the 100% offline baseline.
- `flutter analyze` passes with 0 issues.
- Automated tests cover startup, schedule navigation, bloc behavior, HTTP edge repositories, and responsive rail panel widgets.

## Android
- `android/app/src/main/AndroidManifest.xml` configures permissions and backup.
- Release signing falls back to debug signing when `android/key.properties` is absent.
- `android/app/upload-keystore.jks` exists in repo, but release signing depends on external `key.properties`.

## iOS
- `ios/Runner/Info.plist` includes display name, launch screen, and portrait/landscape support.

## Edge API and Runtime
- Community API configuration keys:
  - `COMMUNITY_API_ENABLED`: `true` (default)
  - `COMMUNITY_API_BASE_URL`: `https://your-project-id.supabase.co`
- Pure Dart HTTP client (`ApiClient`) with zero proprietary backend SDKs or platform-specific service plist/json files.

## Store Readiness Follow-Up
- Add or validate `android/key.properties` for signed release builds.
- Confirm privacy policy and terms endpoints are live in the About panel drawer.
- Run an iOS build sanity check on macOS before App Store submission.
