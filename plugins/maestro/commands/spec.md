---
name: spec
description: "Create and manage feature specifications — structured artifacts consumed by all agents."
argument-hint: "[\"description\"|list|show SLUG|activate SLUG|complete SLUG]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - AskUserQuestion
---

# /maestro spec

**ALWAYS display this ASCII banner as the FIRST thing in your response, before any other output:**

```
███╗   ███╗ █████╗ ███████╗███████╗████████╗██████╗  ██████╗
████╗ ████║██╔══██╗██╔════╝██╔════╝╚══██╔══╝██╔══██╗██╔═══██╗
██╔████╔██║███████║█████╗  ███████╗   ██║   ██████╔╝██║   ██║
██║╚██╔╝██║██╔══██║██╔══╝  ╚════██║   ██║   ██╔══██╗██║   ██║
██║ ╚═╝ ██║██║  ██║███████╗███████║   ██║   ██║  ██║╚██████╔╝
╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝
```

Manage spec-driven workflows. Specs are structured feature specifications that become shared context artifacts for all agents.

---

## Spec File Format

Every spec lives at `.maestro/specs/<slug>.md` and follows this exact structure:

```markdown
---
name: "user-authentication"
title: "User Authentication"
status: draft          # draft | active | implementing | complete | archived
created: 2026-03-18
updated: 2026-03-18
author: rodrigo        # from git config user.name
priority: high         # high | medium | low
stories: []            # populated by /maestro decompose
---

## Problem

[One paragraph: what pain or gap this feature addresses. Who is affected and how.]

## Solution

[One paragraph: what we are building and how it solves the problem.]

## Requirements

- REQ-1: [Specific, testable requirement]
- REQ-2: [Specific, testable requirement]
- REQ-3: [Specific, testable requirement]

## Non-Goals

- [What this spec explicitly does NOT cover]
- [Boundaries that keep scope contained]

## Technical Constraints

- [Technology, performance, or compatibility constraints]
- [Existing systems this must integrate with]

## Acceptance Criteria

- AC-1: Given [context], when [action], then [outcome]
- AC-2: Given [context], when [action], then [outcome]

## Success Metrics

- [Measurable outcome that signals the feature is working]
- [Quantitative target where possible]

## Open Questions

- [Unresolved decision that needs an answer before implementation]
```

**Slug rules:** lowercase, hyphen-separated, derived from the feature name. Example: "User Authentication" → `user-authentication`.

---

## Subcommands

### `/maestro spec "description"`

Create a new spec interactively from a plain-language description.

**Step 1 — Parse the description.**

Extract:
- Key nouns → candidate feature name and slug
- Verbs and intent → draft Problem and Solution paragraphs
- Any quantitative details → candidate Requirements or Success Metrics
- Any mentioned constraints → Technical Constraints

**Step 2 — Generate the draft.**

Produce a complete spec document using the format above. Infer as much as possible from the description; use `[TBD]` for fields that genuinely cannot be inferred. Then present the draft inline so the user can read it.

**Example — input:** `"users should be able to log in with email and password and stay logged in for 30 days"`

**Example — draft output:**

```markdown
---
name: "user-authentication"
title: "User Authentication"
status: draft
created: 2026-03-18
author: rodrigo
priority: medium
stories: []
---

## Problem

Users currently have no way to authenticate. Every page load starts a new anonymous session, making personalization and data persistence impossible.

## Solution

Implement email/password authentication with persistent sessions. Users log in once and remain authenticated for up to 30 days via a secure refresh-token flow.

## Requirements

- REQ-1: Login endpoint accepts email and password, returns access + refresh tokens
- REQ-2: Access token expires after 15 minutes; refresh token expires after 30 days
- REQ-3: Invalid credentials return 401 with a generic error message (no user enumeration)
- REQ-4: Logout invalidates the refresh token server-side

## Non-Goals

- OAuth / social login (separate spec)
- Two-factor authentication (separate spec)

## Technical Constraints

- Must integrate with existing PostgreSQL users table
- Tokens must be JWTs signed with RS256

## Acceptance Criteria

- AC-1: Given valid credentials, when POST /auth/login, then 200 with token pair
- AC-2: Given invalid password, when POST /auth/login, then 401
- AC-3: Given expired access token, when using refresh token, then new access token issued
- AC-4: Given logged-out user, when using old refresh token, then 401

## Success Metrics

- Login endpoint p99 latency < 200ms
- Zero user enumeration vulnerabilities in security audit

## Open Questions

- Should we support "remember me" as a separate 90-day option?
```

**Step 3 — Interactive review flow.**

Use AskUserQuestion:
- Question: "Review the spec draft above. What would you like to do?"
- Header: "Spec Review"
- Options:
  1. label: "Approve — save as draft", description: "Save to .maestro/specs/ with status: draft"
  2. label: "Activate now", description: "Save and immediately set as the active spec"
  3. label: "Edit requirements", description: "Modify the requirements list before saving"
  4. label: "Edit acceptance criteria", description: "Refine the AC before saving"
  5. label: "Discard", description: "Cancel without saving"

**On "Edit requirements" or "Edit acceptance criteria":**
Ask the user to provide the updated text via a follow-up AskUserQuestion with a free-text field, then regenerate the spec with those edits applied and loop back to Step 3.

**On "Approve" or "Activate now":**
- Create `.maestro/specs/` if it does not exist
- Write the spec file to `.maestro/specs/<slug>.md`
- If "Activate now": also run the `activate` flow below
- Confirm: `[maestro] Spec saved: .maestro/specs/user-authentication.md`

---

### `/maestro spec list`

Read all files in `.maestro/specs/`. If the directory does not exist or is empty:

```
[maestro] No specs found. Create one with: /maestro spec "your feature description"
```

Otherwise display:

```
+-------------------------------------------------------------+
| Feature Specifications                                      |
+-------------------------------------------------------------+

  Slug                Status          Req   AC    Created
  ----------------    ------------    ---   ---   ----------
  user-auth           active          4     4     2026-03-18
  api-endpoints       implementing    5     6     2026-03-17
  dashboard-ui        complete        8     10    2026-03-15
  payment-flow        draft           0     0     2026-03-18

  4 specs total  |  1 active  |  1 complete  |  2 other
```

Count Requirements by counting lines matching `- REQ-`. Count AC by counting lines matching `- AC-`.

---

### `/maestro spec show <slug>`

Read `.maestro/specs/<slug>.md`. If not found, fuzzy-match against existing slugs and suggest the closest one.

Display the full spec. For Requirements and Acceptance Criteria, cross-reference `.maestro/state.md` and story files to mark completion:

```
+-------------------------------------------------------------+
| Spec: user-auth  (active)                                   |
+-------------------------------------------------------------+

  Title     User Authentication
  Created   2026-03-18
  Author    rodrigo
  Priority  high
  Stories   S01, S02, S03 (linked)

  ## Requirements
    [x] REQ-1: Login endpoint accepts email/password
    [x] REQ-2: JWT tokens expire after 15 minutes
    [ ] REQ-3: Password reset via email link
    [ ] REQ-4: Logout invalidates refresh token

  ## Acceptance Criteria
    [x] AC-1: Given valid credentials, when POST /auth/login, then 200
    [ ] AC-2: Given invalid password, when POST /auth/login, then 401
    [ ] AC-3: Given expired token, when refreshing, then new token issued

  Progress  2/4 requirements  1/3 AC
```

A requirement is marked `[x]` if a story linked to this spec has `status: done` and explicitly references that REQ id, or if the spec's `updated` date is within an active completed session.

---

### `/maestro spec activate <slug>`

1. Read `.maestro/specs/<slug>.md` — error if not found
2. Check for another currently active spec; if found, warn:
   ```
   [maestro] Warning: user-auth is currently active. Activating api-endpoints will replace it.
   ```
   Confirm with AskUserQuestion before proceeding.
3. Set the target spec's `status` to `active` and update `updated` date
4. Register as T1 context: append to `.maestro/context.md` (or create it):
   ```
   ## Active Spec
   File: .maestro/specs/api-endpoints.md
   Activated: 2026-03-18
   ```
5. Deactivate any previously active spec (set its status to `draft`)
6. Confirm:
   ```
   [maestro] Spec activated: api-endpoints
   (i) All agents will now use this spec as T1 context.
   (i) Run /maestro decompose to generate stories from its requirements.
   ```

---

### `/maestro spec complete <slug>`

1. Read the spec. Identify all `- REQ-` lines and all `- AC-` lines.
2. Cross-reference with story completion data in `.maestro/state.md`.
3. If any requirements or AC are unchecked:
   ```
   [maestro] Warning: 2 requirements and 1 AC are not yet verified complete.
     [ ] REQ-3: Password reset via email link
     [ ] REQ-4: Logout invalidates refresh token
     [ ] AC-3: Given expired token, when refreshing, then new token issued
   ```
   Use AskUserQuestion to confirm: "Mark complete anyway?"
4. Set `status: complete`, update `updated` date
5. Remove from active context in `.maestro/context.md`
6. Confirm:
   ```
   [maestro] Spec completed: user-auth
   (i) Archived from active context.
   (i) Run /maestro ship to include this spec in the PR description.
   ```

---

## Output Contract

Every `spec` invocation emits output in this order:

1. ASCII banner (mandatory)
2. Primary output block (list table, spec body, confirmation message, or draft)
3. AskUserQuestion prompt (for creation flow and activate conflict)

**File writes:**
- Spec files: `.maestro/specs/<slug>.md`
- Active context registration: `.maestro/context.md`
- Never modifies story files directly — that is the decompose command's responsibility

---

## Integration

- **spec-first**: `skills/spec-first/SKILL.md` — enforces that a validated spec exists before any dev-loop starts; auto-generates specs from one-line descriptions and elevates them to T1 context
- **decompose**: reads active spec to generate stories from requirements
- **context-engine**: loads active spec as T1 (always available to all agents)
- **qa-reviewer**: checks implementations against spec AC lines
- **feature-registry**: spec requirements map to registry entries
- **ship**: includes spec completion status in PR description
- **retro**: reports spec completion rate as a quality metric
