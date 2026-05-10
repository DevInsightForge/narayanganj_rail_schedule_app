# Firebase Spark Plan Review

## Current Firebase Surface

### Firestore collections

| Collection | Purpose | Client role after refactor |
| --- | --- | --- |
| `session_status_snapshots` | v2 aggregate community overlay and report state for a train session | Primary read/write path |
| `session_status_snapshots_debug` | Debug-build v2 aggregate community overlay and report state | Debug read/write path |

### Other Firebase services

| Service | Purpose | Spark-safe posture |
| --- | --- | --- |
| Firebase Anonymous Auth | Resolve a stable anonymous uid for auth readiness and write gating | Optional, reused instead of re-bootstrap loops |
| Firebase Remote Config | Schedule payload refresh after initial render | Optional, one-shot, already bounded by minimum fetch interval |
| Firebase App Check | Abuse protection when configured | Optional and non-blocking when disabled |

## Where Reads Happen

### Before refactor

- `RailCommunityInsightCoordinator` queried `station_reports` once per stop in the active session.
- `FirebasePredictionRepository` read the entire `predicted_stops` subcollection.
- Community refresh was triggered on train-context changes and on every 30-second ticker update.

### After refactor

- The app reads only `session_status_snapshots/{sessionId}` for community overlay in normal release flows.
- Overlay payloads are cached locally for 5 minutes per session.
- The 30-second ticker no longer performs Firestore community reads.
- Retry and post-submit refresh can bypass cache intentionally.
- Concurrent overlay fetches for the same session share a single in-flight request.

## Where Writes Happen

### `session_status_snapshots`

- Triggered only after the first successful anonymous Firebase handshake on a device.
- Submission performs one transaction against the session aggregate document.
- The station bucket stores only compact aggregate status fields.
- Same-device duplicate prevention remains local to the service-day-aware ledger.

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
- Current risk: low to moderate, bounded by explicit user actions, local cooldown, in-flight guard, persisted submission ledger, and one aggregate transaction.

### Anonymous identity bootstrap

- Previous risk: unnecessary profile writes if called repeatedly.
- Current risk: low because no profile collection is written by the normal community flow.

## Exact Changes Made

- Added `CommunityOverlayRepository` and `CommunityOverlayResult` as the single optional community-read contract.
- Added `CachedCommunityOverlayRepository` with a 5-minute SharedPreferences-backed cache and in-flight request coalescing.
- Added `FirebaseCommunityOverlayRepository` to read aggregate session overlay docs from `session_status_snapshots/{sessionId}`.
- Reworked `RailCommunityInsightCoordinator` to consume the aggregate overlay path instead of per-stop raw report fan-out.
- Added SharedPreferences-backed arrival submission ledger for client-side duplicate protection.
- Reworked `RailReportCoordinator` to use the ledger, preserve cooldown/rate-limit behavior, and avoid Firestore read-before-write verification.
- Simplified the aggregate document to schema version 2 and removed raw report, profile, and prediction collection assumptions from the normal flow.
- Updated `firestore.rules` to validate the compact v2 aggregate without route-specific station hardcoding or UID storage.
- Updated README to document Spark-safe operating assumptions and anonymous UID marker usage.

## Future Recommendations If Usage Grows Beyond Spark

- Keep `session_status_snapshots/{sessionId}` compact and avoid expanding it into a broad historical store.
- Use console-side/manual aggregate cleanup only if storage growth becomes noticeable.
- If read/write volume materially exceeds Spark limits, move aggregation and retention work to infrastructure that requires Blaze only after product usage justifies it.
- If more community features are added later, prefer aggregate documents and client cache reuse over subcollection polling and listeners.
