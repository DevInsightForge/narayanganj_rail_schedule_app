# Narayanganj Commuter

[![CI](https://github.com/DevInsightForge/narayanganj_rail_schedule_app/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/DevInsightForge/narayanganj_rail_schedule_app/actions/workflows/ci.yml)
[![Publish](https://github.com/DevInsightForge/narayanganj_rail_schedule_app/actions/workflows/publish.yml/badge.svg)](https://github.com/DevInsightForge/narayanganj_rail_schedule_app/actions/workflows/publish.yml)
[![Latest Release](https://img.shields.io/github/v/release/DevInsightForge/narayanganj_rail_schedule_app)](https://github.com/DevInsightForge/narayanganj_rail_schedule_app/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Mobile-first Flutter commuter rail app for the Dhaka-Narayanganj route. The app is centered on a compact rail board that keeps the official timetable as baseline truth and layers real-time community delay signals on top via a Cloudflare Worker edge API.

## Current Status

- Startup is split into bootstrap, composition, and app-shell layers.
- Schedule loading is 100% offline-first with bundled JSON as the canonical timetable baseline.
- Rail UI is compact, monochrome, and optimized for phone-first usage.
- Anonymous arrival reporting and community delay insight are backed by a Cloudflare Worker edge API with HMAC-SHA256 request authentication.
- Zero external database/BaaS client dependencies (pure HTTP REST).
- Community delay insight, freshness, and downstream predictions are provided directly by the edge service as the source of truth.
- Community freshness is aged locally on the board timer; network refreshes happen on board open, route/session changes, explicit retry, foreground interval polling (30s), and successful submissions.
- Pure API mode: no local caching layers or debug bypass logic; edge service handles rate-limiting, route validation, and delay consensus.
- Rail-board orchestration is split into a thin cubit plus bounded feature-local helpers to keep the feature navigable without bloated classes.
- Rail board copy and time formatting live in a small presentation helper so the domain service stays focused on selection and snapshot logic.
- Test-only fakes live under `test/support`, while `lib/` stays focused on runtime code.
- Footer metadata, privacy policy, and terms live in an in-app drawer with static app-owned content.

## Core Features

- Next-train decision board with wait time, ETA, and route context
- Direction, boarding, and destination selection with deterministic state updates
- Journey trace with scheduled stops and predicted downstream timing
- Backup departure list for the active route selection
- Anonymous arrival reporting and community delay aggregation
- Graceful fallback when the community API is disabled, offline, or unreachable

## Schedule and Edge API Behavior

- Bundled schedule JSON is the canonical offline-first baseline.
- Community features communicate over HTTPS with Cloudflare Worker edge endpoints (`GET /overlay?tripId={canonicalId}` and `POST /reports`).
- Requests are authenticated via HMAC-SHA256 signature headers (`x-app-timestamp`, `x-app-signature`) and app `User-Agent`.
- Local anonymous device UUID identity is persisted in `SharedPreferences` without external authentication services.
- The client operates in pure API mode with foreground interval polling (30s) and 1-second local aging.

## Local Setup

```bash
flutter pub get
flutter test
flutter run
```

Optional root `.env`:

```env
# Community delay API configuration (Edge REST API)
COMMUNITY_API_ENABLED=true
COMMUNITY_API_BASE_URL=https://your-edge-worker.example.com
COMMUNITY_API_SECRET=your-hmac-sha256-secret
```

## Release Notes

- Android release requires a configured Android SDK on the build machine.
- Android release signing requires `android/key.properties`.
- Multi-platform desktop and web builds compile with pure Dart networking without native mobile SDK registrants.

## Edge API Architecture & Rate-Limiting

- Edge service hosted on Cloudflare Workers with D1/KV storage.
- Single aggregate record per canonical trip (`dhk-ngj-{trainNo}` and `ngj-dhk-{trainNo}`).
- Cooldown and rate limits (120-second per device) enforced directly at the edge API returning HTTP 429.
- Consensus and delay status calculation (`early`, `onTime`, `minorDelay`, `majorDelay`, `severeDelay`) calculated server-side.
