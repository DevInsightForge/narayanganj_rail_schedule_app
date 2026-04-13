# Changelog

All notable changes to this project should be tracked in this file by release version.

## v1.3.0

- Added a Hive-backed local persistence foundation for community overlay cache, arrival dedupe, pending report queue, and device identity state.
- Hardened startup recovery so corrupted Hive boxes are rebuilt cleanly instead of crashing app launch.
- Tightened report availability so the community button respects the 5 minutes before and 15 minutes after boarding window, already-reported lockout, and syncing state.
- Refined the departure hero layout so train and ETA details render as separate aligned lines.
- Updated community button wording so closed report windows read clearly instead of looking broken.

## v1.2.0

- Reused community session documents across recurring daily runs while keeping `serviceDate` inside the aggregate for clean rollover handling.
- Added a debug-build bypass for community overlay caching and reporting window gating so feature testing stays practical.
- Tightened Firestore rules for the reused session aggregate contract and fixed submit-time permission checks after deployment.
- Moved startup error hooks into bootstrap so app launch wiring stays thinner and easier to maintain.

## v1.1.0

- Reworked community reporting around a single aggregate Firestore document per train session and service day.
- Made the app own aggregate writes transactionally and read the same aggregate back through the cache layer.
- Added bounded per-station submission buckets, station-level capacity handling, and local 18-hour ledger pruning.
- Shortened station reporting windows to 5 minutes before and 15 minutes after the scheduled stop time.
- Derived downstream predicted stop times locally from aggregate delay state instead of relying on separate prediction data.
- Updated Firestore rules, repository contracts, tests, and project docs for the aggregate-first reporting flow.

## v1.0.2

- Enabled Firebase App Check flag.

## v1.0.1

- Replaced hard-coded privacy and terms drawer content with external hyperlinks.
- Moved About content to the top of the footer drawer.
- Tuned the footer drawer sheet height for a more compact presentation.
- Refactored the Firebase community overlay layer to be Spark-safe with cached aggregate reads, persisted submission dedupe, and one-time identity/profile writes.
- Updated Firestore rules and project documentation for Spark-safe retention and operational guidance.
- Added `docs/firebase_spark_plan_review.md` to document Firestore usage, quota risks, and the refactor.
- Refreshed README screenshots.

## v1.0.0

- Promoted the app to a 1.0.0 release with updated package versioning and release workflow support.
- Hardened app startup, Firebase runtime setup, and store/publish configuration.
- Introduced the compact rail board experience with footer details moved into a drawer.
- Completed the schedule-first offline baseline with cached schedule restoration and optional remote schedule sync.
- Added Firebase-backed community arrival reporting, dynamic train session generation, and community delay insights as optional overlays.
- Aligned Firestore rules, Firebase configuration, and release documentation for production rollout.
- Upgraded Firebase and dotenv dependencies for the release baseline.
