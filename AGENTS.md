# AGENTS.md

## Role and Objective
- Build production-ready, maintainable Flutter code for Narayanganj Commuter.
- Preserve the schedule-first baseline while providing low-latency community delay features via Supabase Free Tier PostgREST edge API.
- Keep behavior deterministic, testable, and resilient under degraded connectivity.
- Keep the community layer aggregate-first: one session record per recurring train trip is the source of truth for community delay state, with `serviceDate` stored in the aggregate and reset when the service day changes.

## Architecture Rules
- No spaghetti code.
- Preserve or improve clean architecture.
- Keep clear separation of presentation, application/state, domain, and data/infrastructure.
- Keep business rules out of widgets.
- Isolate HTTP networking and external REST contracts behind repository boundaries.
- Keep domain entities independent from HTTP/JSON DTO shapes.
- Keep DTO models separate from domain models.
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
- Submission flows must model success, failure, cooldown/rate-limit, dedupe, and degraded API outcomes.

## Edge API and Data Rules
- Use official `supabase_flutter` SDK (`SupabaseClient`) for community operations.
- Zero Firebase client dependencies; backend is hosted on Supabase PostgreSQL with PostgREST RPC.
- Use local anonymous device UUID identity (`LocalDeviceIdentityRepository`) for report identity.
- Keep repository interfaces clean for modular backend implementations.
- Keep offline/degraded operation functional with local fallback behavior (Hive + SharedPreferences).
- Bounded aggregate model with per-station buckets and session-level derived fields.
- Derive predicted stop times locally from the aggregate delay plus the active schedule.
- Keep overlay reads cache-first and stale-safe.
- In debug builds, community overlay reads may bypass the cache and reporting may stay enabled outside the normal schedule window to support feature testing.

## Scope Rules
- Chat is out of scope for active milestones.
- Do not introduce chat-specific contracts, entities, repositories, UI, or tests.
- If old chat assumptions are found, remove or mark explicitly postponed in planning docs.

## Workflow Rules
- Keep README.md and AGENTS.md aligned with the current shipped architecture and product scope.
- Keep `.github/workflows/publish.yml` and `.env.example` synchronized with all environment variables consumed by the app.
- Any version bump must be treated as a release change, not a routine edit: update `pubspec.yaml`, update `CHANGELOG.md` with the user-facing changes since the previous version by comparing the previous release tag to the new version commit, and create a matching `vX.Y.Z` tag for the release commit.
- Do not consider a version change complete until the changelog entry and the release tag both exist.
- Document removals and migration tradeoffs in the Decision Log.
- Prefer incremental, reviewable changes.
- When splitting oversized files, keep collaborators nearby and bounded so the module stays easy to navigate.
- When architecture changes, update docs for source of truth, degraded behavior, and edge operational assumptions in the same change.

## Definition of Done
- Code, tests, and docs are complete.
- AGENTS.md and README.md stay current.
- No feature is done without critical state handling and tests.
- Schedule baseline remains useful offline when the community API is unavailable.
- Community features are not done unless aggregate write/read behavior, cache fallback, and session-date scoping are covered by tests.

## Commit Guidance
- Format commits as: `scope: what did the changed was for`.
- Include clear commit intention in descriptions.
- Sign commits.
- Do not add co-authors.
