# Spec — [Feature Name]

---
name: "[Feature Name]"
status: draft
created: [YYYY-MM-DD]
author: [name or "auto-generated"]
priority: [low | medium | high | critical]
source: "[original one-line description, if auto-generated]"
---

## Problem Statement

[What problem does this solve? Why does it need to exist? Who experiences this problem and how often?
Minimum 20 words. Be specific — avoid "users need a better experience."]

## Acceptance Criteria

Each criterion must be testable. Use BDD format where it helps clarity.

- [ ] AC-1: [Concrete, verifiable outcome — e.g., "Given a logged-in user, when they click the toggle, the UI switches to dark mode and the preference persists across page reloads"]
- [ ] AC-2: [Another verifiable outcome]
- [ ] AC-3: [Another verifiable outcome]
<!-- Add more as needed. Minimum 3. Each criterion becomes a story-level gate. -->

## Architecture Decisions

Decisions that constrain or guide implementation. Every decision here is binding — agents cannot override them.

- **[Decision 1 name]:** [What was decided and why. E.g., "CSS variables only: theming must use CSS custom properties, not JS-based style injection, to avoid FOUC and keep SSR compatibility"]
- **[Decision 2 name]:** [Another binding decision]
<!-- Add more as needed. At least 1 required. -->

## Constraints

Hard limits the implementation must respect. If none apply, write "None."

- [Constraint 1 — e.g., "Must be backward compatible with the current API contract"]
- [Constraint 2 — e.g., "No new npm dependencies without approval"]
- [Constraint 3 — e.g., "Must work in all browsers that ship in the current browser-targets.json"]

## Non-Goals

What this feature explicitly does NOT do. Critical for preventing scope creep.

- [Non-goal 1 — e.g., "Per-component theming overrides"]
- [Non-goal 2 — e.g., "System-level dark mode detection (separate story)"]
<!-- If nothing is explicitly out of scope, write "None identified." -->

## Definition of Done

How do we know this feature is complete? These become the final acceptance gates.

- [ ] All acceptance criteria above are checked off
- [ ] [Metric 1 — e.g., "Lighthouse performance score does not drop below current baseline"]
- [ ] [Metric 2 — e.g., "No new TypeScript errors introduced"]
- [ ] [Metric 3 — e.g., "Feature works in Chrome, Firefox, and Safari"]

---

<!-- Notes for the spec author:

1. All six sections must be non-empty before this spec can be activated.
2. Once activated (status: active), Acceptance Criteria are frozen — create a v2 spec to add scope.
3. Architecture Decisions override lower-tier context (story patterns, DNA) — keep them precise.
4. Non-goals are as important as goals — they prevent unbounded scope in decompose.
5. This template lives at templates/spec.md. The spec-first skill uses it for auto-generation.

-->
