# Changelog

All notable changes to this project should be tracked in this file by release version.

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
