# Narayanganj Commuter

[![CI](https://github.com/DevInsightForge/narayanganj_rail_schedule_app/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/DevInsightForge/narayanganj_rail_schedule_app/actions/workflows/ci.yml)
[![Publish](https://github.com/DevInsightForge/narayanganj_rail_schedule_app/actions/workflows/publish.yml/badge.svg)](https://github.com/DevInsightForge/narayanganj_rail_schedule_app/actions/workflows/publish.yml)
[![Latest Release](https://img.shields.io/github/v/release/DevInsightForge/narayanganj_rail_schedule_app)](https://github.com/DevInsightForge/narayanganj_rail_schedule_app/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Mobile-first Flutter commuter rail app for the Dhaka-Narayanganj route. The app is centered on a compact rail board that keeps the official timetable as baseline truth and layers optional anonymous community delay signals on top via a Supabase Free Tier PostgREST edge API.

## Current Status

- Startup is split into bootstrap, composition, and app-shell layers.
- Schedule loading is 100% offline-first with bundled JSON as the canonical timetable baseline.
- Rail UI is compact, monochrome, and optimized for phone-first usage.
- Anonymous arrival reporting and community delay insight are backed by Supabase Free Tier (PostgreSQL + PostgREST), eliminating standalone backend repository maintenance.
- Zero Firebase client dependencies; official Supabase Flutter SDK (`supabase_flutter`) used for community delay operations.
- Community delay insight, freshness, and downstream predictions are derived from session aggregates and remain isolated from the official schedule baseline.
- Community freshness is aged locally on the board timer; network refreshes happen on board open, route/session changes, explicit retry, and successful submissions instead of on every tick.
- Rail-board orchestration is split into a thin cubit plus bounded feature-local helpers to keep the feature navigable without bloated classes.
- Rail board copy and time formatting live in a small presentation helper so the domain service stays focused on selection and snapshot logic.
- Test-only fakes live under `test/support`, while `lib/` stays focused on runtime code.
- Footer metadata, privacy policy, and terms live in an in-app drawer with static app-owned content.

## Core Features

- Next-train decision board with wait time, ETA, and route context
- Direction, boarding, and destination selection with deterministic state updates
- Journey trace with scheduled stops and optional predicted downstream timing
- Backup departure list for the active route selection
- Anonymous arrival reporting and community delay aggregation
- Graceful fallback when the community API is disabled, offline, or unreachable

## Schedule and Edge API Behavior

- Bundled schedule JSON is the canonical offline-first baseline.
- Community features communicate over HTTPS with Supabase PostgREST endpoints (`/rest/v1/session_snapshots` and `/rest/v1/rpc/submit_arrival_report`).
- Local anonymous device UUID identity is persisted in `SharedPreferences` / `Hive` without external authentication services.
- The client reads overlays through a cache-first layer in release builds (90s cache TTL) to minimize network roundtrips.
- Cached aggregate overlays are served when fresh, kept usable for a short stale window (up to 5m), and fall back to timetable baseline if expired.
- Debug builds bypass the overlay cache and keep community reporting enabled outside the normal schedule window for feature testing.

## Local Setup

```bash
flutter pub get
flutter test
flutter run
```

Optional root `.env`:

```env
# Community delay API configuration (Supabase Free Tier PostgREST)
COMMUNITY_API_ENABLED=true
COMMUNITY_API_BASE_URL=https://your-project-id.supabase.co
COMMUNITY_API_KEY=your-supabase-anon-key
```

## Release Notes

- Android release requires a configured Android SDK on the build machine.
- Android release signing requires `android/key.properties`.
- Multi-platform desktop and web builds compile with pure Dart networking without native mobile SDK registrants.

## Edge API Architecture & Rate-Limiting

- Co-located SQL migrations in `supabase/migrations/0001_init.sql`.
- Single aggregate record per recurring daily train trip (`session_snapshots`), reused with `service_date` scoping.
- Deduplication ledger (`report_ledger`) is partitioned by `service_date` with automatic 48-hour `pg_cron` roll-off, keeping storage under 15 MB (<500 MB quota).
- Atomic 120-second cooldown enforced on `device_rate_limits` table with transaction-level advisory locks to eliminate rush-hour lock contention.
- Multi-tier statistical consensus (Median / IQR outlier elimination) ensures single-actor spam cannot manipulate delay statuses.
