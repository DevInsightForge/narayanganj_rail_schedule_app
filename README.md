# Narayanganj Commuter

[![CI](https://github.com/DevInsightForge/narayanganj_rail_schedule_app/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/DevInsightForge/narayanganj_rail_schedule_app/actions/workflows/ci.yml)
[![Publish](https://github.com/DevInsightForge/narayanganj_rail_schedule_app/actions/workflows/publish.yml/badge.svg)](https://github.com/DevInsightForge/narayanganj_rail_schedule_app/actions/workflows/publish.yml)
[![Latest Release](https://img.shields.io/github/v/release/DevInsightForge/narayanganj_rail_schedule_app)](https://github.com/DevInsightForge/narayanganj_rail_schedule_app/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Mobile-first Flutter commuter rail app for the Dhaka-Narayanganj route. The app centers on a schedule-first rail board that treats the bundled timetable as canonical offline truth while layering real-time crowd-sourced arrival reports via a Cloudflare Workers Edge REST API.

---

## Core Features

- **Decision Board:** Next-train departures with wait time, journey duration, and ETA.
- **Directional Station Filtering:** Direction selection, boarding station picker, and downstream-only destination filtering.
- **Journey Timeline:** Stop-by-stop progress with scheduled departure times.
- **Community Updates:** Real-time delay status, freshness aging, and crowdsourced reporting.
- **Graceful Degradation:** Clean fallback to offline baseline when network or API is unavailable.

---

## Getting Started

### Prerequisites
- Flutter SDK (stable channel)
- Dart SDK

### Installation & Run

```bash
flutter pub get
flutter test
flutter run
```

### Environment Configuration
Optional root `.env` for community API integration (see `.env.example`):

```env
COMMUNITY_API_ENABLED=true
COMMUNITY_API_BASE_URL=https://your-edge-worker.example.com
COMMUNITY_API_SECRET=your-hmac-sha256-secret
```

---

## Architecture & Development Standards

### Clean Architecture Boundaries
- **Layer Separation:** Strict separation across `presentation`, `application/state`, `domain`, and `data/infrastructure`.
- **Domain Independence:** Domain entities and services are pure Dart with zero dependencies on widgets, external libraries, or HTTP/JSON DTOs. Keep DTO models separate from domain entities.
- **Repository Isolation:** Network calls, HTTP clients (`EdgeHmacClient`), and external storage live behind repository abstractions (`CommunityRepository`).
- **Separation of Concerns:** Business and timetable logic belongs in `RailBoardService`, not inside widgets. State orchestration and API dispatching belong in `RailBoardCubit`.
- **No Comments in Source Code:** Do not add code comments or inline explanations in source files.

### State Management & UI Rules
- **Explicit States:** Always model loading, success, empty, stale, error, and degraded states intentionally.
- **Atomic Selectors:** Use fine-grained `BlocSelector` slices in presentation to prevent unnecessary widget rebuilds.
- **Design Tokens:** Follow industrial-minimalist monochrome design. Never scatter raw styling or hardcoded colors across widgets; consume tokens from `RailBoardTokens`.
- **Accessibility:** Clamped font scaling (0.85x–1.35x) and responsiveness across mobile and desktop wide screens.
- **Scope Limit:** Chat features are out of scope. Do not introduce chat-specific contracts, entities, UI, or tests.

### Edge API & Community Delay Contracts
- **Authority:** Pure API mode. The Cloudflare Workers Edge API is the source of truth for delay consensus, freshness, and reporting availability (`isReportingAvailable`).
- **Security:** Authenticate client requests using HMAC-SHA256 headers (`x-app-timestamp`, `x-app-signature`) and the app `User-Agent`.
- **Device Identity:** Anonymous device UUID persisted in `SharedPreferences` without external auth SDKs.
- **Offline Baseline:** Bundled timetable JSON remains 100% operational offline when the API is disabled or unreachable.

---

## Testing & Quality Assurance

All features, refactors, and bug fixes must maintain full test coverage:

```bash
flutter analyze
flutter test
```

- Tests live under `test/`, with shared fakes and test harnesses under `test/support/`.
- Community features require test coverage for edge error handling, 409 conflict, 429 rate limit, and server-driven reporting availability.

---

## Release Procedure

Releases are strictly automated via GitHub Actions on Git version tags (`.github/workflows/publish.yml`).

### 1. Verification Gate
Ensure working tree on `main` is clean, bundled schedule works offline, and checks pass:
```bash
flutter analyze
flutter test
```

### 2. Version & Documentation Alignment
- **`pubspec.yaml`**: Bump `version: X.Y.Z+BUILD` (increment build number monotonically).
- **`lib/src/features/rail/presentation/widgets/rail_board_texts.dart`**: Synchronize `appVersion = 'X.Y.Z'`.
- **`CHANGELOG.md`**: Add `## vX.Y.Z` section summarizing user-facing changes since the last tag (`git log $(git describe --tags --abbrev=0)..HEAD --oneline`).
- **`README.md`**: Update if architectural, operational, or environment requirements changed.

### 3. Release Commit
Stage the updated files and commit using the signed format:
```bash
git add pubspec.yaml CHANGELOG.md lib/src/features/rail/presentation/widgets/rail_board_texts.dart README.md
git commit -s -m "release: vX.Y.Z" -m "- Bump version to X.Y.Z+BUILD in pubspec.yaml\n- Add vX.Y.Z release notes to CHANGELOG.md"
```

### 4. Tagging
Create an annotated release tag matching the pubspec version:
```bash
git tag -a vX.Y.Z -m "vX.Y.Z"
```

### 5. Publishing
Push commit and tag to `origin/main` to trigger the automated GitHub Actions publish workflow:
```bash
git push origin main
git push origin vX.Y.Z
```

### 6. Pipeline Behavior
The `publish.yml` workflow triggers on `v*` tags and automatically:
1. Validates that the tag commit is directly on `origin/main`.
2. Validates that `v$PUBSPEC_VERSION` strictly matches the release tag.
3. Restores release signing credentials from `ANDROID_SIGNING_KEY`.
4. Builds release Android App Bundle (`.aab`), universal APK, and per-ABI split APKs.
5. Publishes a GitHub Release with build assets attached.
6. Invokes the notification webhook script hook.
