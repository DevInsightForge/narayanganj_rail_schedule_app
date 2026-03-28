# PLANS.md

## Project Overview
Narayanganj Rail Schedule is evolving into a schedule-first, community-powered train status companion for the Narayanganj route. Official timetable remains baseline truth. Community reports and inferred predictions are a secondary signal layer powered by Firebase client SDKs.

## Current State Assessment
- Layered architecture exists across presentation, domain, and data.
- Baseline schedule flow is stable and offline-capable with bundled and cached fallback.
- Session modeling, arrival reporting, delay classification, confidence scoring, and prediction derivation are implemented.
- Report submission state flow includes submitting, success, rate-limited, error, and offline-queue statuses.
- Community insight state now models loading, ready, stale, and empty.
- Firebase bootstrap and repository integrations are implemented with resilient fallback to local fake repositories.
- Community insight flow now handles repository failures with explicit degraded error state.
- Offline-queued reports now retry on periodic ticks with dedupe and cooldown-aware sync attempts.
- Legacy chat planning/contracts existed previously and have been removed from active code and roadmap.

## Product Vision
Provide a clear, trustworthy commuter companion where users always see official schedule first and optionally benefit from structured, anonymous community arrival signals and explainable delay predictions.

## Product Principles
- Preserve schedule-first behavior.
- Keep reporting low-friction.
- Aggregate reports before presenting status.
- Distinguish official, community, and inferred values clearly.
- Use anonymous identity with optional display name.
- Keep predictions modest and labeled with freshness/confidence.
- Preserve graceful degraded/offline behavior.

## Constraints and Assumptions
- No mandatory signup.
- Firebase client SDK only.
- No Admin SDK, no Cloud Functions requirement, no paid backend requirement for MVP.
- Tight report eligibility window: scheduled departure `-15m` to `+90m`.
- Confidence v1 uses deterministic recency + agreement.
- Client-side safeguards are layered but not perfect abuse prevention.

## Domain Model Draft
- `ScheduleTemplate`
- `StationStop`
- `TrainSession`
- `ArrivalReport`
- `SessionStatusSnapshot`
- `PredictedStopTime`
- `DeviceIdentity`
- `AnonymousProfile`
- `ReportConfidence`
- `ModerationFlag`
- `RateLimitPolicy`

## Firebase Data Model Draft
- `train_sessions/{sessionId}`
  - `sessionId`, `templateId`, `routeId`, `directionId`, `trainNo`, `serviceDate`, `stops[]`
- `station_reports/{reportId}`
  - `reportId`, `sessionId`, `routeId`, `stationId`, `reporterUid`, `observedArrivalAt`, `submittedAt`, `displayName`
- `session_status_snapshots/{sessionId}/predicted_stops/{stationId}`
  - `sessionId`, `stationId`, `predictedAt`, `referenceStationId`, `confidence`, `freshnessSeconds`
- `user_profiles/{uid}`
  - `uid`, `displayName`, `lastSeenAt`, `updatedAt`

## Security Rules Considerations
- Require authenticated user for writes using Firebase Anonymous Auth.
- Restrict report writes so `reporterUid == request.auth.uid`.
- Validate essential fields (`sessionId`, `stationId`, timestamps) and enforce bounded payload shape.
- Restrict profile writes to own `uid` document.
- Use App Check where possible for abuse reduction.
- Document tradeoff: without trusted backend, validation and abuse prevention remain partially client- and rule-based.

## Feature Breakdown
- Baseline schedule browsing and route selection.
- Session resolution and eligibility modeling.
- One-tap arrival reporting.
- Delay classification and downstream prediction.
- Confidence/freshness presentation and stale handling.
- Anonymous identity bootstrap and optional profile.
- Rate-limit/cooldown and dedupe safeguards.
- Firebase-backed sync with resilient local fallback.

## Milestone-Based Release Plan
### Milestone 0: Scope Reconciliation and Chat Removal
- Objective: align docs/code with Firebase-only, no-chat scope.
- Scope: AGENTS/PLANS updates and chat artifact removal.
- Architecture impact: removes obsolete contracts and DI wiring.
- Key tasks: remove chat entities/repositories/tests/docs references.
- Acceptance criteria: no active chat scope in code or plans.
- Risks/dependencies: none.
- Test expectations: regression tests pass.

### Milestone 1: Firebase Foundation Setup
- Objective: initialize Firebase client infrastructure safely.
- Scope: runtime bootstrap, env-driven Firebase options, App Check scaffolding.
- Architecture impact: infrastructure entrypoint added, no UI coupling.
- Key tasks: bootstrap implementation, env keys, fallback runtime behavior.
- Acceptance criteria: app runs with Firebase enabled or disabled.
- Risks/dependencies: configuration errors.
- Test expectations: bootstrap/options tests.

### Milestone 2: Anonymous Identity Integration
- Objective: use Firebase Anonymous Auth behind identity abstraction.
- Scope: identity repository and profile persistence integration.
- Architecture impact: identity moves to infrastructure boundary.
- Key tasks: auth bootstrap, profile read/write, last-seen updates, fallback.
- Acceptance criteria: identity resolves without mandatory signup.
- Risks/dependencies: auth unavailable scenarios.
- Test expectations: identity abstraction and fallback tests.

### Milestone 3: Firestore Arrival Reporting Integration
- Objective: persist and read structured arrival reports via Firestore.
- Scope: report repository Firebase implementation + resilient fallback.
- Architecture impact: data source expands with Firestore DTO mappings.
- Key tasks: submit/read report docs, mapper coverage, rule-friendly fields.
- Acceptance criteria: report flow works with Firebase and degrades safely.
- Risks/dependencies: Firestore indexes/rules.
- Test expectations: repository mapping and submission flow tests.

### Milestone 4: Firestore Session Status and Prediction Sync
- Objective: support Firebase-synced predicted stop data while preserving local derivation.
- Scope: prediction repository Firebase implementation + bloc integration.
- Architecture impact: remote prediction sync added to insight derivation path.
- Key tasks: fetch predicted stop docs, merge/fallback strategy, stale handling.
- Acceptance criteria: estimates remain labeled and confidence-aware.
- Risks/dependencies: sparse remote snapshot coverage.
- Test expectations: state transitions and fallback prediction tests.

### Milestone 5: Anti-Spam and Degraded Hardening
- Objective: strengthen abuse safeguards and degraded behavior.
- Scope: cooldown, dedupe, local queue resilience, auth failure handling.
- Architecture impact: application safeguards tightened.
- Key tasks: enforce cooldown policy, improve queue behavior, rule assumptions docs.
- Acceptance criteria: stable reporting behavior under failures and retries.
- Risks/dependencies: client-only abuse limits.
- Test expectations: cooldown/duplicate/offline tests.

### Milestone 6: Release Hardening and Documentation
- Objective: finish rollout-readiness with cleanup and QA.
- Scope: regression hardening, docs finalization, milestone closure.
- Architecture impact: stabilization only.
- Key tasks: remove stale assumptions, verify UX states, finalize docs.
- Acceptance criteria: schedule baseline plus community overlay are stable.
- Risks/dependencies: environment setup drift.
- Test expectations: full suite plus targeted smoke coverage.

## Risks and Open Questions
- Firestore rules cannot fully prevent intentional abuse without server-side validation.
- Session document freshness and ownership of derived snapshots need operational governance.
- Production App Check provider configuration remains environment-dependent.
- Route/session document publishing workflow to Firestore needs explicit operational process.

## Test Strategy
- Domain tests: lifecycle, delay classification, confidence, prediction propagation.
- Repository tests: DTO mapping, resilient fallback, submission/read behavior.
- Identity tests: anonymous identity abstraction and fallback behavior.
- State tests: reporting and insight transitions including stale/empty/degraded.
- Regression tests: schedule baseline and remote fallback behavior.

## Progress Tracker
- [x] Milestone 0 complete.
- [x] Milestone 1 initial implementation complete.
- [x] Milestone 2 initial implementation complete.
- [x] Milestone 3 initial implementation complete.
- [x] Milestone 4 initial implementation complete.
- [x] Milestone 5 initial implementation complete.
- [ ] Milestone 6 pending release hardening.

## Decision Log
- 2026-03-28: Kept schedule-first baseline as non-negotiable.
- 2026-03-28: Chose tight reporting eligibility window (`-15m` to `+90m`).
- 2026-03-28: Chose recency+agreement confidence model for v1.
- 2026-03-28: Removed chat from product and technical scope.
- 2026-03-28: Adopted Firebase client-only integration strategy for MVP.
- 2026-03-28: Implemented Firebase bootstrap with env-driven options and App Check scaffolding.
- 2026-03-28: Implemented Firebase repositories for sessions, reports, predictions, and identity with resilient local fallback.
- 2026-03-28: Added Firestore mapping tests and resilient repository tests to support migration safety.
- 2026-03-28: Removed remaining chat lifecycle remnants from domain service and tests.
- 2026-03-28: Added queued report retry drain on tick with bounded dedupe retention and rate-limit-aware sync attempts.
- 2026-03-28: Added explicit community insight error state fallback when repository calls fail.
