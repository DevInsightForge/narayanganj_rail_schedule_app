# AGENTS.md

## Role and Objective
- Build production-ready, maintainable Flutter code for Narayanganj Commuter.
- Preserve the schedule-first baseline while adding Firebase-backed community status features.
- Keep behavior deterministic, testable, and resilient under degraded connectivity.
- Keep the community layer aggregate-first: one Firestore document per train session/day is the source of truth for community delay state.

## Architecture Rules
- No spaghetti code.
- Preserve or improve clean architecture.
- Keep clear separation of presentation, application/state, domain, and data/infrastructure.
- Keep business rules out of widgets.
- Isolate Firebase SDK usage behind repository and data-source boundaries.
- Keep domain entities independent from Firebase DTO/document shapes.
- Keep DTO/document models separate from domain models.
- Prefer composition over inheritance.
- Follow SOLID pragmatically.
- Follow DRY without harming clarity.

## Code Quality Rules
- No god classes.
- No duplicate business logic.
- No hidden side effects.
- Use explicit, intention-revealing names.
- Avoid oversized files when concepts should be extracted.
- Prefer a small number of feature-local collaborators over giant classes or file-per-method fragmentation.
- Keep the rail-board use-case and controller split into a small number of feature-local helpers instead of one giant class or a file-per-method layout.
- Keep presentation copy and label formatting out of domain services when a small feature-local helper can own it cleanly.
- New code must be null-safe, testable, and deterministic where possible.
- No comments in source code.

## Flutter and UI Rules
- Keep theming consistent.
- Do not scatter raw styling tokens across widgets.
- Keep interactions low-friction and focused.
- Include loading, empty, error, stale, and degraded states where relevant.
- Preserve responsiveness and schedule-first UX.

## State Management Rules
- Keep state transitions explicit and testable.
- Separate domain/application state from transient widget state.
- Model loading, success, empty, stale, error, and degraded states intentionally.
- Submission flows must model success, failure, cooldown/rate-limit, dedupe, and degraded Firebase outcomes.

## Firebase and Data Rules
- Use Firebase client SDK only.
- No Firebase Admin SDK.
- No Cloud Functions or custom backend as a requirement for MVP.
- Use Firebase Anonymous Auth for identity bootstrap.
- Keep Crashlytics error reporting optional and gated separately from the core Firebase data path.
- Keep Firestore model and writes security-rules-friendly.
- Keep repository interfaces clean for future backend migration.
- Keep offline/degraded operation functional with local fallback behavior.
- Use `session_status_snapshots/{sessionId}` as the only Firestore-backed community session record in normal app flows.
- Do not introduce `station_reports`, chat collections, prediction collections, or other parallel community truth sources.
- Keep aggregate documents bounded with per-station buckets and session-level derived fields.
- Derive predicted stop times locally from the aggregate delay plus the active schedule.
- Keep overlay reads cache-first and stale-safe.

## Scope Rules
- Chat is out of scope for active milestones.
- Do not introduce chat-specific contracts, entities, repositories, UI, or tests.
- If old chat assumptions are found, remove or mark explicitly postponed in planning docs.

## Workflow Rules
- Keep README.md and AGENTS.md aligned with the current shipped architecture and product scope.
- Keep `.github/workflows/publish.yml` and `.env.example` synchronized with all environment variables consumed by the app.
- Document removals and migration tradeoffs in the Decision Log.
- Prefer incremental, reviewable changes.
- When splitting oversized files, keep collaborators nearby and bounded so the module stays easy to navigate.
- When architecture changes, update docs for source of truth, degraded behavior, and Firestore operational assumptions in the same change.

## Definition of Done
- Code, tests, and docs are complete.
- AGENTS.md and README.md stay current.
- No feature is done without critical state handling and tests.
- Schedule baseline remains useful offline when Firebase is unavailable.
- Community features are not done unless aggregate write/read behavior, cache fallback, and session-date scoping are covered by tests.

## Commit Guidance
- Format commits as: `scope: what did the changed was for`.
- Include clear commit intention in descriptions.
- Sign commits.
- Do not add co-authors.
