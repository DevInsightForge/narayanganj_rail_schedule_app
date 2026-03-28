# Narayanganj Commuter

[![CI](https://github.com/DevInsightForge/narayanganj_rail_schedule_app/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/DevInsightForge/narayanganj_rail_schedule_app/actions/workflows/ci.yml)
[![Publish](https://github.com/DevInsightForge/narayanganj_rail_schedule_app/actions/workflows/publish.yml/badge.svg)](https://github.com/DevInsightForge/narayanganj_rail_schedule_app/actions/workflows/publish.yml)
[![Latest Release](https://img.shields.io/github/v/release/DevInsightForge/narayanganj_rail_schedule_app)](https://github.com/DevInsightForge/narayanganj_rail_schedule_app/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Mobile-first Flutter commuter rail app for the Dhaka-Narayanganj route. The app is centered on a compact rail board that keeps the official timetable as baseline truth and layers optional anonymous community delay signals on top.

## Current Status

- Startup is split into bootstrap, composition, and app-shell layers.
- Schedule loading is offline-first with bundled JSON as baseline, cached restoration, and Firebase Remote Config as a silent post-render update path.
- Rail UI is compact, monochrome, and optimized for phone-first usage.
- Anonymous Firebase-backed arrival reporting remains optional and secondary to the published schedule.
- Community delay insight, freshness, and downstream prediction remain isolated from the official schedule baseline.
- Footer metadata, privacy policy, and terms now live in an in-app drawer with static app-owned content.

## Core Features

- Next-train decision board with wait time, ETA, and route context
- Direction, boarding, and destination selection with deterministic state updates
- Journey trace with scheduled stops and optional predicted downstream timing
- Backup departure list for the active route selection
- Anonymous arrival reporting and community delay aggregation
- Graceful fallback when Firebase is disabled, unavailable, or partially degraded

## Schedule and Firebase Behavior

- Bundled schedule JSON is the non-negotiable baseline.
- Cached schedule data restores quickly when available.
- Firebase Remote Config can deliver versioned schedule updates after initial render.
- Firebase Anonymous Auth, Firestore, and App Check are optional at runtime and can be disabled through env configuration.
- Community features are hidden or degraded safely when Firebase is unavailable.

## Local Setup

```bash
flutter pub get
flutter test
flutter run
```

Optional root `.env`:

```env
# Optional override: set to false to disable Firebase.
FIREBASE_ENABLED=true
FIREBASE_APPCHECK_ENABLED=false

# Minimal required Firebase env values.
FIREBASE_PROJECT_ID=
FIREBASE_API_KEY=

# Optional platform-specific API key overrides.
FIREBASE_WEB_API_KEY=
FIREBASE_ANDROID_API_KEY=
FIREBASE_IOS_API_KEY=

# Optional web analytics / App Check web config.
FIREBASE_MEASUREMENT_ID=
FIREBASE_APPCHECK_WEB_KEY=
```

## Release Notes

- Android release requires a configured Android SDK on the build machine.
- Android release signing requires `android/key.properties`.
- Android Firebase-backed release behavior may require `android/app/google-services.json` depending on your release setup.
- If `FIREBASE_APPCHECK_ENABLED=true`, Firebase App Check must already be configured in Firebase Console for the target platform.

## Firebase Security Baseline

- Firestore config is versioned in [firebase.json](firebase.json), [firestore.rules](firestore.rules), and [firestore.indexes.json](firestore.indexes.json).
- Train sessions are generated dynamically from bundled schedule templates using deterministic session IDs.
- `station_reports` writes require Firebase Anonymous Auth and enforce `reporterUid == request.auth.uid`.
- `session_status_snapshots` is read-only to clients.
- `user_profiles` is owner-write metadata only with no client reads.

## Firestore Retention

- Configure Firestore TTL for `station_reports.submittedAt` with a 7-day policy in Firebase Console.
- Keep `firestore.rules` aligned with TTL by enforcing report writes within the same 7-day server-time window.

## Showcase

### Header and Decision Panel
![Header and decision panel](docs/screenshots/01-header-decision-panel.png)

### Journey Trace Panel
![Journey trace panel](docs/screenshots/02-journey-trace-panel.png)

### Upcoming Trains Panel
![Upcoming trains panel](docs/screenshots/03-upcoming-trains-panel.png)
