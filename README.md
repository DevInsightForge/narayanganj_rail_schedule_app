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
- Community delay insight, freshness, and downstream prediction are derived from a single session aggregate document and remain isolated from the official schedule baseline.
- Session documents are reused across recurring daily train runs; `serviceDate` remains stored inside the aggregate so the document can reset cleanly when the day changes.
- Rail-board orchestration is split into a thin cubit plus bounded feature-local helpers, including a smaller use-case layer, to keep the feature navigable without making the codebase a maze.
- Rail board copy and time formatting live in a small presentation helper so the domain service stays focused on selection and snapshot logic.
- Test-only fakes live under `test/support`, while `lib/` stays focused on runtime code.
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
- Crashlytics error reporting is optional at runtime and can be enabled separately from the core Firebase data path.
- Community features are enabled only after Firebase initializes successfully and degrade safely when it does not.
- Community overlay reads and arrival-report writes are centered on `session_status_snapshots/{sessionId}`, which acts as the canonical aggregate document for a recurring train session.
- The client updates that document transactionally and reads it through a cache-first overlay layer in release builds to keep Firestore usage predictable on Spark.
- The aggregate document stores bounded per-station buckets, session-level delay/confidence fields, and no separate raw Firestore report log.
- Cached aggregate overlays are served when fresh and reused as stale fallback when Firestore is unavailable or temporarily empty.
- Debug builds bypass the overlay cache and keep community reporting enabled outside the normal schedule window so feature testing stays practical.

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
FIREBASE_CRASHLYTICS_ENABLED=false

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
- If `FIREBASE_CRASHLYTICS_ENABLED=true`, Crashlytics collection is enabled only after Firebase initializes successfully for that build.

## Firebase Security Baseline

- Firestore config is versioned in [firebase.json](firebase.json), [firestore.rules](firestore.rules), and [firestore.indexes.json](firestore.indexes.json).
- Train sessions are generated dynamically from bundled schedule templates using deterministic session IDs.
- `session_status_snapshots/{sessionId}` is the canonical aggregate document for a recurring train session.
- `session_status_snapshots/{sessionId}` is reused for the same recurring train run, with `serviceDate` stored inside the aggregate to keep stale day state from leaking forward.
- Arrival report submission updates that aggregate document transactionally after Firebase Anonymous Auth is ready.
- Repeated reports from the same device for the same session/station are bounded by a persisted local ledger that is service-day aware and do not expand the aggregate beyond one bucket per station.
- The client derives predicted stop times from the aggregate delay and the current session schedule.
- Arrival reporting UI stays hidden until anonymous auth readiness resolves, while community overlay insight can still render independently.
- Debug builds can bypass the community overlay cache and schedule-window gating for reporting so feature testing stays available outside the normal active window.

## Firebase Spark Plan Considerations

- Firestore is used only for optional community-driven signals:
  - transactional updates to `session_status_snapshots/{sessionId}`
  - aggregate session overlay reads from `session_status_snapshots/{sessionId}`
- Spark free-tier limits to design around:
  - `50,000` document reads per day
  - `20,000` document writes per day
  - `20,000` document deletes per day
  - `1 GiB` stored data
  - `10 GiB` outbound data per month
- The app does not rely on Firestore TTL, PITR, backups, restore, or clone. Those are not assumed available for this app's operating model.
- Retention strategy is Spark-safe:
  - Firestore is treated as a short-horizon community signal store, not long-term truth
  - the client only reads and writes one narrow session aggregate doc and caches it locally for 5 minutes
  - report submission uses client-side cooldown, dedupe, and a persisted submission ledger to avoid read-before-write verification
- Recommended operational guidance:
  - keep `session_status_snapshots/{sessionId}` compact and aggregate-oriented
  - avoid realtime listeners for community overlay data
  - avoid broad historical scans and per-stop polling
  - prefer schedule-only mode if Firebase is misconfigured or degraded
- Risky patterns to avoid:
  - querying many stops individually for the same train session
  - depending on separate predicted-stop subcollections
  - depending on Firestore cleanup features that require Blaze billing
- The app remains fully usable with Firebase disabled or degraded because the official bundled/cached timetable stays offline-first.

