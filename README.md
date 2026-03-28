# Narayanganj Rail Schedule

[![CI](https://github.com/DevInsightForge/narayanganj_rail_schedule_app/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/DevInsightForge/narayanganj_rail_schedule_app/actions/workflows/ci.yml)
[![Publish](https://github.com/DevInsightForge/narayanganj_rail_schedule_app/actions/workflows/publish.yml/badge.svg)](https://github.com/DevInsightForge/narayanganj_rail_schedule_app/actions/workflows/publish.yml)
[![Latest Release](https://img.shields.io/github/v/release/DevInsightForge/narayanganj_rail_schedule_app)](https://github.com/DevInsightForge/narayanganj_rail_schedule_app/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Mobile-first Flutter commuter rail app for the Dhaka-Narayanganj route. It turns dense timetable data into a fast decision board for everyday trips.

## Features

- Next-train decision view with ETA, wait time, and route context
- Direction, boarding, and destination switching with deterministic state reconciliation
- Remote schedule loading from fixed website API endpoint with strict validation
- Safe fallback chain: `remote API -> cached valid payload -> bundled static data`
- Community arrival reporting with anonymous Firebase identity
- Community delay and downstream prediction insights with confidence and freshness labels
- Resilient Firebase sync with local fallback and offline queue behavior
- Structured logging for remote loading branches and validation failures
- Android system bars styled to match app surface (no default gray status bar)

## Remote Data Configuration

The app derives schedule API URL from `WEBSITE_BASE_URL`.

- Base URL env key: `WEBSITE_BASE_URL`
- Derived schedule URL: `<WEBSITE_BASE_URL>/api/schedule/data.json`
- Default base URL: `https://narayanganj-rail-schedule.pages.dev/`

## Local Setup

```bash
flutter pub get
flutter test
flutter run
```

Optional root `.env`:

```env
WEBSITE_BASE_URL=https://narayanganj-rail-schedule.pages.dev/
FIREBASE_ENABLED=false
FIREBASE_APPCHECK_ENABLED=false
FIREBASE_API_KEY=
FIREBASE_APP_ID=
FIREBASE_MESSAGING_SENDER_ID=
FIREBASE_PROJECT_ID=
FIREBASE_AUTH_DOMAIN=
FIREBASE_STORAGE_BUCKET=
FIREBASE_IOS_BUNDLE_ID=
FIREBASE_MEASUREMENT_ID=
FIREBASE_APPCHECK_WEB_KEY=
```

## Firebase Security Baseline

- Firestore config is versioned in [firebase.json](firebase.json), [firestore.rules](firestore.rules), and [firestore.indexes.json](firestore.indexes.json).
- `station_reports` writes require Firebase Anonymous Auth and enforce `reporterUid == request.auth.uid`.
- `train_sessions` and `session_status_snapshots` are read-only to clients.
- `user_profiles` is restricted to owner read/write.

## Showcase

### Header and Decision Panel
![Header and decision panel](docs/screenshots/01-header-decision-panel.png)

### Journey Trace Panel
![Journey trace panel](docs/screenshots/02-journey-trace-panel.png)

### Upcoming Trains Panel
![Upcoming trains panel](docs/screenshots/03-upcoming-trains-panel.png)
