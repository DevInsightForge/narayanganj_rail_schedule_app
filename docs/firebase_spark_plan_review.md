# Firebase Spark Plan Review

## Current Firebase Surface

### Firestore collections

| Collection | Purpose | Client role after refactor |
| --- | --- | --- |
| `station_reports` | Anonymous arrival reports for a session and station | Write-only in normal app flow |
| `session_status_snapshots` | Aggregate community overlay for a train session | Primary read path |
| `session_status_snapshots/{sessionId}/predicted_stops` | Legacy prediction subcollection | Deprecated for normal app reads |
| `user_profiles` | Anonymous device bootstrap metadata | One-time write on successful handshake |

### Other Firebase services

| Service | Purpose | Spark-safe posture |
| --- | --- | --- |
| Firebase Anonymous Auth | Resolve a stable anonymous uid for report writes | Optional, reused instead of re-bootstrap loops |
| Firebase Remote Config | Schedule payload refresh after initial render | Optional, one-shot, already bounded by minimum fetch interval |
| Firebase App Check | Abuse protection when configured | Optional and non-blocking when disabled |

## Where Reads Happen

### Before refactor

- `RailCommunityInsightCoordinator` queried `station_reports` once per stop in the active session.
- `FirebasePredictionRepository` read the entire `predicted_stops` subcollection.
- Community refresh was triggered on train-context changes and on every 30-second ticker update.

### After refactor

- The app reads only `session_status_snapshots/{sessionId}` for community overlay in normal flows.
- Overlay payloads are cached locally for 5 minutes per session.
- The 30-second ticker no longer performs Firestore community reads.
- Retry and post-submit refresh can bypass cache intentionally.
- Concurrent overlay fetches for the same session share a single in-flight request.

## Where Writes Happen

### `station_reports`

- Triggered only by an explicit user arrival-report submission.
- Client writes remain create-only with session, station, route, reporter uid, and timestamps.
- The app no longer performs read-before-write duplicate verification against Firestore.

### `user_profiles`

- Triggered only after the first successful anonymous Firebase handshake on a device.
- Repeated launches and refreshes reuse persisted handshake state and skip profile writes.

## Risk Analysis By Feature

### Schedule baseline

- Risk to Spark: low.
- Schedule data remains bundled and cached locally.
- Remote Config stays optional and secondary.

### Community overlay

- Previous risk: high read amplification from per-stop report queries plus subcollection prediction reads.
- Current risk: low to moderate, bounded by one doc read per active session per 5-minute cache window.

### Report submission

- Previous risk: moderate due to duplicate verification reads and repeated identity/profile touches.
- Current risk: low to moderate, bounded by explicit user actions, local cooldown, in-flight guard, and persisted submission ledger.

### Anonymous identity bootstrap

- Previous risk: unnecessary `user_profiles` writes if called repeatedly.
- Current risk: low because profile writes are one-time and handshake state is persisted.

## Exact Changes Made

- Added `CommunityOverlayRepository` and `CommunityOverlayResult` as the single optional community-read contract.
- Added `CachedCommunityOverlayRepository` with a 5-minute SharedPreferences-backed cache and in-flight request coalescing.
- Added `FirebaseCommunityOverlayRepository` to read aggregate session overlay docs from `session_status_snapshots/{sessionId}`.
- Reworked `RailCommunityInsightCoordinator` to consume the aggregate overlay path instead of per-stop raw report fan-out.
- Added SharedPreferences-backed arrival submission ledger and switched duplicate prevention to local persisted state.
- Reworked `RailReportCoordinator` to use the ledger, preserve cooldown/rate-limit behavior, and avoid Firestore read-before-write verification.
- Added persisted Firebase identity state and changed `FirebaseDeviceIdentityRepository` so `user_profiles` is written once per device handshake instead of repeatedly.
- Tightened `station_reports` raw fetch limit to `10` for remaining non-UI/raw access paths.
- Updated `firestore.rules` to use a 2-hour recency guard for submitted reports instead of a TTL-coupled 7-day assumption.
- Updated README to document Spark-safe operating assumptions and removed TTL guidance.

## Future Recommendations If Usage Grows Beyond Spark

- Keep `session_status_snapshots/{sessionId}` compact and avoid expanding it into a broad historical store.
- Add console-side/manual cleanup for old `station_reports` once storage growth becomes noticeable.
- If read/write volume materially exceeds Spark limits, move aggregation and retention work to infrastructure that requires Blaze only after product usage justifies it.
- If more community features are added later, prefer aggregate documents and client cache reuse over subcollection polling and listeners.
