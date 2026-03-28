# AGENTS.md

## Role and Objective
- Build production-ready, maintainable Flutter code for Narayanganj Rail Schedule.
- Preserve the schedule-first experience while incrementally adding community-powered capabilities.
- Optimize for clear architecture boundaries, deterministic behavior, and offline resilience.

## Architecture Rules
- No spaghetti code.
- Preserve or improve clean architecture boundaries across presentation, state/application, domain, and data/infrastructure.
- Keep business logic out of widgets.
- Keep backend transport details out of UI and domain layers.
- Use pragmatic SOLID and DRY without harming readability.
- Favor composition over inheritance.
- Add abstractions only when they improve clarity or backend integration seams.

## Code Quality Rules
- No god classes.
- No large unstructured files when concepts should be extracted.
- No duplicate business logic across widgets, blocs, services, repositories, and helpers.
- Use explicit, intention-revealing names.
- Prefer simple and extensible designs over clever shortcuts.
- New code must be null-safe, deterministic, and testable.
- No comments in source code.

## Flutter and UI Rules
- Maintain consistent theming strategy through centralized tokens and palette abstractions.
- Do not scatter raw values for colors, spacing, radii, shadows, and text styles.
- Include loading, empty, stale/degraded, and error states for new user-visible features.
- Keep responsive behavior aligned with existing patterns.
- Prefer accessible and clear UI copy and controls.

## State Management Rules
- Keep state transitions explicit and testable.
- Separate transient UI state from domain/application state.
- Do not embed domain calculations in event handlers or widgets.
- Model loading, success, empty, stale, degraded, and error states deliberately where relevant.

## Data and Integration Rules
- Define repository contracts before backend-dependent implementation.
- Keep DTOs separate from domain entities.
- Keep fake/mock implementations behind interfaces.
- Support graceful offline and degraded operation.
- Avoid hardcoded backend assumptions that increase migration cost.

## Workflow Rules
- Before major implementation, update PLANS.md with objective, scope, impact, and tradeoffs.
- After each milestone increment, update PLANS.md progress tracker, decisions, risks, and follow-ups.
- Prefer incremental, reviewable changes over broad rewrites.
- Preserve working offline behavior at every step.

## Definition of Done
- Code, tests, docs, and PLANS.md updates are complete.
- AGENTS.md and PLANS.md remain current.
- New integration contracts are documented.
- New user-visible states include loading/empty/error handling.
- Existing schedule baseline remains functional when community/live systems are unavailable.

## Commit Guidance
- Format commits as: `scope: what did the changed was for`.
- Include clear commit intention in descriptions.
- Sign commits.
- Do not add co-authors.