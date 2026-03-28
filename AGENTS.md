# AGENTS.md

## Role and Objective
- Build production-ready, maintainable Flutter code for Narayanganj Commuter.
- Preserve the schedule-first baseline while adding Firebase-backed community status features.
- Keep behavior deterministic, testable, and resilient under degraded connectivity.

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
- Submission flows must model success, failure, cooldown/rate-limit, and offline-queue outcomes.

## Firebase and Data Rules
- Use Firebase client SDK only.
- No Firebase Admin SDK.
- No Cloud Functions or custom backend as a requirement for MVP.
- Use Firebase Anonymous Auth for identity bootstrap.
- Keep Firestore model and writes security-rules-friendly.
- Keep repository interfaces clean for future backend migration.
- Keep offline/degraded operation functional with local fallback behavior.

## Scope Rules
- Chat is out of scope for active milestones.
- Do not introduce chat-specific contracts, entities, repositories, UI, or tests.
- If old chat assumptions are found, remove or mark explicitly postponed in planning docs.

## Workflow Rules
- Before major implementation, update PLANS.md.
- After each milestone or major refactor, update PLANS.md with progress and decisions.
- Document removals and migration tradeoffs in the Decision Log.
- Prefer incremental, reviewable changes.

## Definition of Done
- Code, tests, docs, and PLANS updates are complete.
- AGENTS.md and PLANS.md stay current.
- No feature is done without critical state handling and tests.
- Schedule baseline remains useful offline when Firebase is unavailable.

## Commit Guidance
- Format commits as: `scope: what did the changed was for`.
- Include clear commit intention in descriptions.
- Sign commits.
- Do not add co-authors.
