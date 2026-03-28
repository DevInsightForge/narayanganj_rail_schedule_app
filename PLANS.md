# PLANS.md

## Project Overview
Narayanganj Commuter is evolving into a schedule-first, community-powered train status companion for the Narayanganj route. Official timetable remains baseline truth. Community reports and inferred predictions are a secondary signal layer powered by Firebase client SDKs.

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
- Use anonymous identity without profile setup.
- Keep predictions modest and labeled with freshness/confidence.
- Preserve graceful degraded/offline behavior.

## Constraints and Assumptions
- No mandatory signup.
- Firebase client SDK only.
- No Admin SDK, no Cloud Functions requirement, no paid backend requirement for MVP.
- Tight report eligibility window for commuter operations: scheduled departure `-5m` to `+60m`.
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
- `ReportConfidence`
- `ModerationFlag`
- `RateLimitPolicy`

## Firebase Data Model Draft
- Virtual `train_sessions` generated client-side from schedule templates:
  - `sessionId = <routeId>:<directionId>:<trainNo>:<YYYYMMDD>`
  - `serviceDate`, stop sequence, and schedule timestamps are deterministic from bundled timetable.
- `station_reports/{reportId}`
  - `reportId`, `sessionId`, `routeId`, `stationId`, `reporterUid`, `observedArrivalAt`, `submittedAt`
- `session_status_snapshots/{sessionId}/predicted_stops/{stationId}`
  - `sessionId`, `stationId`, `predictedAt`, `referenceStationId`, `confidence`, `freshnessSeconds`
- `user_profiles/{uid}`
  - `uid`, `lastSeenAt`, `updatedAt`

## Security Rules Considerations
- Require authenticated user for writes using Firebase Anonymous Auth.
- Restrict report writes so `reporterUid == request.auth.uid`.
- Validate essential fields (`sessionId`, `stationId`, timestamps) and enforce bounded payload shape.
- Keep report timestamps within a recent 7-day server-time window.
- Restrict profile metadata writes to own `uid` document and keep profile reads disabled at rule level.
- Use App Check where possible for abuse reduction.
- Keep rules/indexes versioned in repo (`firestore.rules`, `firestore.indexes.json`, `firebase.json`) to avoid drift.
- Document tradeoff: without trusted backend, validation and abuse prevention remain partially client- and rule-based.
- Configure Firestore TTL on `station_reports.submittedAt` to enforce automatic cleanup after 7 days.

## Feature Breakdown
- Baseline schedule browsing and route selection.
- Session resolution and eligibility modeling.
- One-tap arrival reporting.
- Delay classification and downstream prediction.
- Confidence/freshness presentation and stale handling.
- Anonymous identity bootstrap.
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

### Milestone 7: Operational Session Publishing Workflow
- Objective: replace persisted session-doc dependency with deterministic dynamic session generation.
- Scope: local/generated session repository, runtime wiring cleanup, and retention rule hardening.
- Architecture impact: removes unnecessary remote session collection dependency and simplifies operations.
- Key tasks: generate sessions on-demand from schedule templates, remove seed export tooling, enforce 7-day report write window.
- Acceptance criteria: app resolves current/next sessions without `train_sessions` collection and report lifecycle is bounded.
- Risks/dependencies: deterministic session ID contract must stay stable across clients.
- Test expectations: generated-session repository tests and regression validation.

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
- [x] Milestone 6 complete.
- [x] Milestone 7 complete.

## Decision Log
- 2026-03-28: Kept schedule-first baseline as non-negotiable.
- 2026-03-28: Tuned reporting eligibility window for short intercity commuter behavior (`-5m` to `+60m`).
- 2026-03-28: Chose recency+agreement confidence model for v1.
- 2026-03-28: Removed chat from product and technical scope.
- 2026-03-28: Adopted Firebase client-only integration strategy for MVP.
- 2026-03-28: Implemented Firebase bootstrap with env-driven options and App Check scaffolding.
- 2026-03-28: Implemented Firebase repositories for sessions, reports, predictions, and identity with resilient local fallback.
- 2026-03-28: Added Firestore mapping tests and resilient repository tests to support migration safety.
- 2026-03-28: Removed remaining chat lifecycle remnants from domain service and tests.
- 2026-03-28: Added queued report retry drain on tick with bounded dedupe retention and rate-limit-aware sync attempts.
- 2026-03-28: Added explicit community insight error state fallback when repository calls fail.
- 2026-03-28: Added Firebase Firestore rules/indexes config files to lock a client-only MVP security baseline.
- 2026-03-28: Standardized Firebase initialization on env-driven options with minimal required keys (`FIREBASE_PROJECT_ID`, `FIREBASE_API_KEY`) and derived domains (`authDomain`, `storageBucket`) while keeping platform app IDs hardcoded.
- 2026-03-28: Removed anonymous profile/display name abstraction from active community reporting flow, repositories, DTOs, and Firestore report rules to keep participation fully anonymous and low-friction.
- 2026-03-28: Tightened `user_profiles` rules to owner-write metadata only with client reads disabled.
- 2026-03-28: Hardened Firebase env parsing so blank values are treated as missing to reduce release-time misconfiguration risk.
- 2026-03-28: Closed Milestone 6 after release hardening, security-rule tightening, anonymous-flow cleanup, and regression test verification.
- 2026-03-28: Replaced persisted `train_sessions` dependency with deterministic dynamic session generation from local templates and removed seed-export tooling.
- 2026-03-28: Enforced 7-day report timestamp window in Firestore rules to align with automatic cleanup policy.
- 2026-03-28: Added explicit operational requirement to enable Firestore TTL on `station_reports.submittedAt` for automatic 7-day cleanup.

