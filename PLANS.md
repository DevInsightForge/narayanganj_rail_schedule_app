# PLANS.md

## Project Overview
Narayanganj Rail Schedule will evolve from a static schedule board into a community-powered train session companion while preserving schedule-first reliability and offline usefulness.

## Current State Assessment
- App architecture is layered: presentation (`widgets`, `bloc`) -> domain (`entities`, `services`) -> data (`repository`, `parser`, `datasource`).
- Bundled schedule data remains primary baseline and can run fully offline.
- Schedule loading path already supports `remote -> cached -> bundled` fallback behavior.
- Domain currently models timetable and trip selection; no date-specific train session model exists.
- No community reports, confidence model, prediction model, session chat, or device identity model exists.
- Some formatting logic is duplicated in UI widgets and should move to domain/application services where appropriate.
- State model currently covers loading, ready, and failure but not stale or degraded community states.
- Existing tests cover parser, schedule repository fallback, service basics, and bloc startup.

## Product Vision
Build a community-driven rail companion for the Narayanganj line where published timetable remains official baseline and community signals add practical real-time context.

## Product Principles
- Preserve schedule-first usability.
- Keep participation low-friction with one-tap actions.
- Aggregate community signals before presenting conclusions.
- Keep users anonymous by default with optional display name.
- Scope chat to train sessions and valid time windows.
- Keep predictions modest, explainable, and confidence-labeled.
- Preserve graceful degradation and offline usability.

## Constraints and Assumptions
- No mandatory login.
- Backend is not available yet.
- App-side architecture must define backend integration seams early.
- Tight session eligibility window: scheduled departure `-15m` to `+90m`.
- Confidence v1: deterministic recency + agreement scoring.
- API modeling style: REST JSON draft contracts.
- Schedule/session computations follow Bangladesh local time semantics.

## Domain Model Draft
- `ScheduleTemplate`: recurring schedule definition for a direction and train number.
- `StationStop`: station sequence and scheduled local time.
- `TrainSession`: date-scoped running instance derived from template.
- `ArrivalReport`: rider observation for station arrival.
- `SessionStatusSnapshot`: derived session state for UI consumption.
- `PredictedStopTime`: inferred downstream timing estimate with confidence.
- `SessionChatThread`: session-scoped, time-bounded chat thread.
- `DeviceIdentity`: persistent device-scoped anonymous identity.
- `AnonymousProfile`: optional user display name.
- `ReportConfidence`: score metadata based on recency and agreement.
- `ModerationFlag`: moderation and anti-abuse signaling fields.

## API Contract Draft
- `GET /v1/routes/{routeId}/sessions?serviceDate=YYYY-MM-DD`
- `GET /v1/routes/{routeId}/sessions/next-status?fromStationId=&toStationId=&now=ISO8601`
- `POST /v1/sessions/{sessionId}/arrival-reports`
- `GET /v1/sessions/{sessionId}/stops/{stationId}/reports`
- `GET /v1/sessions/{sessionId}/predictions`
- `GET /v1/sessions/{sessionId}/chat`
- `POST /v1/sessions/{sessionId}/chat/messages`
- `POST /v1/devices/handshake`
- `GET /v1/devices/{deviceId}/rate-limit-metadata`
- All relevant payloads must include source tags: `official`, `community`, `inferred`, plus freshness and confidence metadata.

## Feature Breakdown
- Session lifecycle and eligibility modeling.
- Community arrival reporting and conflict-aware aggregation.
- Delay classification and downstream prediction.
- Session-scoped chat eligibility and thread scaffolding.
- Anonymous profile, device identity, and anti-spam controls.
- Degraded/offline behavior hardening.

## Milestone-Based Release Plan
### Milestone 0: Discovery, Guardrails, Planning
- Objective: establish rules and delivery framework.
- Scope: AGENTS.md and PLANS.md creation/update.
- Architecture impact: none.
- Key tasks: codify rules, capture current assessment, define milestones and contracts.
- Acceptance criteria: docs complete and current.
- Risks/dependencies: none.
- Test expectations: none.

### Milestone 1: Domain Expansion for Sessions and Community Core
- Objective: add backend-agnostic domain model and lifecycle rules.
- Scope: TrainSession model, report model, confidence model, lifecycle services.
- Architecture impact: new community domain module.
- Key tasks: session derivation, eligibility logic, delay classification, confidence scaffolding.
- Acceptance criteria: deterministic pure-domain behavior and tests.
- Risks/dependencies: overnight schedule handling.
- Test expectations: lifecycle and classification tests.

### Milestone 2: Repository Contracts and Integration Seams
- Objective: define app-facing contracts and fake implementations.
- Scope: repositories for sessions, reports, predictions, chat, identity, rate-limit metadata.
- Architecture impact: explicit domain-data boundary for future backend.
- Key tasks: interface definitions, fake/in-memory adapters, composition-root wiring.
- Acceptance criteria: app runs with fake repositories and unchanged schedule flow.
- Risks/dependencies: DTO coupling risk.
- Test expectations: repository contract tests.

### Milestone 3: Community Arrival Reporting Flow
- Objective: one-tap report flow for eligible sessions.
- Scope: action entry point, submit pipeline, optimistic/local queued behavior.
- Architecture impact: new app state for report submission outcomes.
- Key tasks: dedupe key, rate-limit prechecks, offline queue.
- Acceptance criteria: reports allowed only in valid windows.
- Risks/dependencies: spam before backend controls.
- Test expectations: state and eligibility tests.

### Milestone 4: Delay and Prediction Presentation
- Objective: show status and downstream predictions with confidence/freshness.
- Scope: session status and timeline enhancements.
- Architecture impact: aggregation services become UI-facing via view state.
- Key tasks: conflict-aware aggregation, bounded propagation, explainable labels.
- Acceptance criteria: inferred values are clearly labeled as estimates.
- Risks/dependencies: sparse report data.
- Test expectations: aggregation and widget rendering tests.

### Milestone 5: Session Chat Eligibility and Scaffold
- Objective: add chat constrained to session context.
- Scope: thread view, message fetch/post via interfaces, eligibility guards.
- Architecture impact: session context routing for chat.
- Key tasks: enforce window constraints and session binding.
- Acceptance criteria: no global chat leakage.
- Risks/dependencies: moderation backend absent.
- Test expectations: eligibility and UI state tests.

### Milestone 6: Identity and Anti-Spam Scaffold
- Objective: support anonymous identity with local anti-abuse primitives.
- Scope: persistent device identity and optional display name.
- Architecture impact: identity service and persistence layer.
- Key tasks: ID generation, local cooldown/rate-limit checks.
- Acceptance criteria: no mandatory login and persistent identity.
- Risks/dependencies: server-side enforcement pending.
- Test expectations: identity persistence and throttling tests.

### Milestone 7: Hardening and Release Readiness
- Objective: stabilize degraded/offline behavior and quality gates.
- Scope: stale states, failure recovery, QA and regression sweep.
- Architecture impact: stabilization.
- Key tasks: improve degraded messaging and operational readiness.
- Acceptance criteria: schedule-first baseline remains reliable offline.
- Risks/dependencies: edge regressions across windows.
- Test expectations: full suite and targeted smoke tests.

## Risks and Open Questions
- Balancing strict eligibility windows with report participation in delayed runs.
- Handling conflicting reports with low sample counts.
- Defining backend moderation and abuse response policy.
- Final cache invalidation and reconciliation policy when backend arrives.

## Test Strategy
- Domain tests for lifecycle, overnight rollover, delay status, confidence scoring.
- Repository tests for contracts and fake adapter determinism.
- State tests for load/success/empty/stale/error/degraded transitions.
- Widget tests for schedule baseline and future community entry points.
- Edge cases: overnight sessions, stale reports, conflicting reports, no network, no community data.

## Progress Tracker
- [x] Milestone 0 started and documented.
- [x] Milestone 1 domain foundation implemented with tests.
- [x] Milestone 2 repository contracts, fake adapters, mapper scaffolding, and DI wiring implemented with tests.
- [ ] Milestone 3 implementation pending.
- [ ] Milestone 4-7 pending.

## Decision Log
- 2026-03-28: Adopted milestone-first migration with schedule baseline preserved at all times.
- 2026-03-28: Selected tight session/chat/report eligibility window (`-15m` to `+90m`).
- 2026-03-28: Selected recency+agreement confidence model for v1.
- 2026-03-28: Selected REST JSON contract style for backend draft.
- 2026-03-28: Added community domain model, session lifecycle service, delay classifier, confidence scoring, consensus aggregation, and downstream prediction scaffolding.
- 2026-03-28: Added backend-facing repository interfaces and in-memory fake implementations for sessions, reports, predictions, chat, identity, and rate-limit policies.
- 2026-03-28: Added `RailSchedule` to `ScheduleTemplate` mapper to bridge existing static schedule into date-scoped TrainSession creation flow.
