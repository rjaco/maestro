---
name: story-validator
description: "Pre-dispatch validator that checks stories are self-contained before sending them to an implementer agent. Blocks dispatch on hard failures; logs warnings and proceeds on soft failures."
---

# Story Validator

Pre-dispatch completeness checker for story files. Runs 8 rules against a story before the dev-loop dispatches an implementer agent. The goal is to catch missing context early — before a wasted agent turn — rather than letting the implementer report NEEDS_CONTEXT.

## When to Use

- Called automatically by dev-loop Phase 1 (VALIDATE) before every implementer dispatch
- Called manually via `/story-validator .maestro/stories/NN-slug.md`
- Called by the decompose skill after story generation to catch template gaps

## Input

- **story** — Path to the story markdown file (from `$ARGUMENTS`)
- **strict** — Optional: `true` | `false` (default: `false`). In strict mode, warnings are treated as failures and block dispatch.

## Validation Rules

Run all 8 rules in order. Each rule produces one of three outcomes:

| Symbol | Outcome | Meaning |
|--------|---------|---------|
| `(ok)` | PASS | Rule satisfied |
| `(!)`  | WARNING | Soft issue — dispatch proceeds, warning is logged |
| `(x)`  | FAIL | Hard failure — dispatch is blocked |

---

### V1: Frontmatter Complete

**Check:** Parse the YAML frontmatter block. Verify all required fields are present and non-empty.

**Required fields:**

| Field | Valid Values |
|-------|-------------|
| `id` | integer |
| `slug` | non-empty kebab-case string |
| `title` | non-empty string |
| `type` | `frontend`, `backend`, `integration`, `data`, `infrastructure` |
| `depends_on` | list (may be empty `[]`) |
| `model_recommendation` | `haiku`, `sonnet`, `opus` |
| acceptance criteria | at least one Given/When/Then block in the story body |

**Fail condition:** Any required field is missing or empty. Acceptance criteria section absent or empty.

**Output examples:**
```
  (ok) V1: Frontmatter complete (7/7 required fields)
  (x)  V1: Frontmatter incomplete — missing fields: model_recommendation, type
```

---

### V2: Acceptance Criteria Specific

**Check:** Read every criterion in the Acceptance Criteria section. A testable criterion must contain:
1. An action verb (Given/When/Then, or equivalent imperative form)
2. An observable, concrete outcome — not a vague quality judgment

**Vague patterns that trigger failure:**
- "works correctly"
- "is good"
- "functions properly"
- "handles it"
- "behaves as expected"
- "is valid"
- "looks right"

**Fail condition:** One or more criteria match a vague pattern or contain no observable outcome.

**Output examples:**
```
  (ok) V2: Acceptance criteria specific (5 criteria, all testable)
  (x)  V2: Vague acceptance criteria — AC3 contains "works correctly", AC5 contains "is good"
```

---

### V3: File Paths Exist

**Check:** Parse the Files section. For each listed path:

| Tag | Expectation |
|-----|-------------|
| `Create` | Path does NOT need to exist (will be created) — skip existence check |
| `Modify` | Path MUST exist on disk |
| `Reference` | Path MUST exist on disk |

**Fail condition:** Any `Modify` or `Reference` path does not resolve to an existing file.

**Output examples:**
```
  (ok) V3: File paths exist (2 modify, 1 reference — all found)
  (x)  V3: Missing paths — Modify: src/lib/auth.ts (not found), Reference: src/types/user.ts (not found)
```

---

### V4: Dependencies Resolved

**Check:** Read the `depends_on` list from frontmatter. For each story ID in the list, look up its status in `.maestro/state.md` (or `.maestro/state.local.md`).

**Fail condition:** Any dependency story has status `PENDING` or `IN_PROGRESS`.

**Pass condition (automatic):** If `depends_on` is empty (`[]`), this rule passes with "no dependencies".

**Output examples:**
```
  (ok) V4: Dependencies resolved (M1-01: DONE, M1-02: DONE)
  (ok) V4: Dependencies resolved (none)
  (x)  V4: Unresolved dependencies — M1-02: IN_PROGRESS, M1-03: PENDING
```

---

### V5: Architecture Context Present

**Check:** If the story `type` is `backend`, `frontend`, or `fullstack`, verify that the story body contains an Architecture Decisions (or Architecture Context) section that:
1. Is present (not missing)
2. Is non-empty
3. Does not consist only of placeholder text (`TBD`, `TODO`, `[placeholder]`, `[add context here]`, or equivalent)

**Warning condition (not failure):** Section exists but is thin (fewer than 3 non-empty lines of actual content). Thin sections get a `(!)` warning instead of `(x)` failure — they may be intentionally brief for simple stories.

**Fail condition:** Section is entirely absent, or contains only placeholder text.

**Skip condition:** Story type is `data` or `infrastructure` — rule does not apply; mark as `(ok) V5: N/A (type: data)`.

**Output examples:**
```
  (ok) V5: Architecture context present (12 lines)
  (!)  V5: Architecture context thin (2 lines) — agent may need context escalation
  (x)  V5: Architecture context missing — add inline pattern for API routes
  (ok) V5: N/A (type: data)
```

---

### V6: No Upstream References

**Check:** Scan the story body for patterns that point the implementer to external documents instead of embedding context inline.

**Patterns that trigger failure:**
- `see [filename]`
- `refer to [document]`
- `check [file]`
- `as described in [doc]`
- `documented in [file]`
- `see CLAUDE.md`
- `see architecture.md`
- `see [section] in [file]`

**Rationale:** These references break the self-contained contract. The agent reads only the story file. Any context in an external doc must be inlined.

**Fail condition:** Story body contains one or more upstream reference patterns.

**Output examples:**
```
  (ok) V6: No upstream references
  (x)  V6: Upstream references found — line 34: "see CLAUDE.md for auth patterns", line 67: "refer to architecture.md"
```

---

### V7: Project Rules Inline

**Check:**

1. Determine if a `CLAUDE.md` exists in the project root (or any parent directory up to the repo root).
2. If `CLAUDE.md` does not exist, skip this rule: `(ok) V7: N/A (no CLAUDE.md found)`.
3. If `CLAUDE.md` exists, check whether the story body contains a Project Rules section with at least one rule that is relevant to the story's files and type.

**Relevance heuristic:** A rule is relevant if it mentions any of the directories, file extensions, or patterns that appear in the story's Files section. For example, a `CLAUDE.md` rule for `src/app/api/` is relevant to a story that modifies files under `src/app/api/`.

**Warning condition (not failure):** `CLAUDE.md` exists but the story's file paths don't clearly match any extractable rules — mark `(!)` with a note that manual review may be needed.

**Fail condition:** `CLAUDE.md` exists, contains rules that are clearly relevant to the story's files/type, and the story's Project Rules section is empty or absent.

**Output examples:**
```
  (ok) V7: Project rules inline (3 rules from CLAUDE.md for src/app/api/)
  (!)  V7: CLAUDE.md exists but relevance unclear — review manually
  (x)  V7: Project rules empty — CLAUDE.md has 3 applicable rules for src/app/api/
  (ok) V7: N/A (no CLAUDE.md found)
```

---

### V8: Complexity Matches Model

**Check:** Verify that the story's `model_recommendation` field is consistent with the story's apparent complexity.

**Mismatch definitions:**

| Complexity Signal | Recommended Floor | Violation |
|-------------------|------------------|-----------|
| Story modifies 7+ files | `sonnet` | `haiku` |
| Story type is `integration` or `infrastructure` | `sonnet` | `haiku` |
| Story has 5+ acceptance criteria | `sonnet` | `haiku` |
| Story contains security-sensitive keywords (`auth`, `token`, `payment`, `crypto`, `password`, `PII`) | `sonnet` | `haiku` |
| Story `depends_on` has 3+ entries | `sonnet` | `haiku` |
| Any of the above at double threshold (14+ files, 10+ ACs) | `opus` | `haiku` or `sonnet` |

**Fail condition:** `haiku` is recommended for a story that meets one or more floor conditions above.

**Warning condition:** `sonnet` is recommended when signals suggest `opus` territory (double-threshold signals). This is a `(!)` warning — sonnet may be adequate but is worth flagging.

**Note:** This rule does not enforce upward precision. Recommending `opus` for a simple story is expensive but not a blocker.

**Output examples:**
```
  (ok) V8: Complexity (medium) matches model (sonnet)
  (ok) V8: Complexity (simple) matches model (haiku)
  (!)  V8: Complexity signals suggest opus — 10 ACs, 8 files; sonnet may be insufficient
  (x)  V8: Model mismatch — haiku recommended for story with 8 files and auth keywords (floor: sonnet)
```

---

## Output Format

```
Story Validation: [story-id] — [story-title]
  [outcome] V1: [message]
  [outcome] V2: [message]
  [outcome] V3: [message]
  [outcome] V4: [message]
  [outcome] V5: [message]
  [outcome] V6: [message]
  [outcome] V7: [message]
  [outcome] V8: [message]

  Result: [PASS | BLOCKED | WARNINGS]
```

**Result line variants:**

| Outcome | Result Line |
|---------|-------------|
| All rules pass | `Result: PASS` |
| No failures, 1+ warnings | `Result: WARNINGS — N warning(s) logged to .maestro/context-log.md` |
| 1+ failures | `Result: BLOCKED — N failure(s) (V#, V#), M warning(s) (V#)` |

When BLOCKED, add a fix guidance line for each failure:
```
  Fix V7 before dispatch. V5 is a warning — dispatch will proceed but agent may need context escalation.
```

**Full example:**
```
Story Validation: M1-03 — API Routes
  (ok) V1: Frontmatter complete (7/7 required fields)
  (ok) V2: Acceptance criteria specific (5 criteria, all testable)
  (ok) V3: File paths exist (2 modify, 1 reference — all found)
  (ok) V4: Dependencies resolved (M1-01: DONE, M1-02: DONE)
  (!)  V5: Architecture context missing — add inline pattern for API routes
  (ok) V6: No upstream references
  (x)  V7: Project rules empty — CLAUDE.md has 3 applicable rules for src/app/api/
  (ok) V8: Complexity (medium) matches model (sonnet)

  Result: BLOCKED — 1 failure (V7), 1 warning (V5)
  Fix V7 before dispatch. V5 is a warning — dispatch will proceed but agent may need context escalation.
```

---

## Integration Points

### With Dev Loop

Dev-loop Phase 1 (VALIDATE) calls story-validator before every implementer dispatch:

```
Phase 1: VALIDATE
  1. Run /story-validator .maestro/stories/NN-slug.md
  2. If BLOCKED:
       - Return to decompose step
       - Show the BLOCKED output to the user
       - Ask user to fix the story or re-run decompose with more context
  3. If WARNINGS:
       - Append warnings to .maestro/context-log.md
       - Proceed to Phase 2 (DELEGATE)
  4. If PASS:
       - Proceed to Phase 2 (DELEGATE)
```

### With Decompose

After generating stories, decompose may call story-validator to catch template gaps before writing final story files. If any story is BLOCKED at generation time, decompose fills the gaps before saving.

### With Context Log

Warnings are appended to `.maestro/context-log.md` in this format:

```markdown
## [YYYY-MM-DD] Story Validation Warnings

**Story:** M1-03 — API Routes
**Dispatched at:** [timestamp]

- V5: Architecture context thin (2 lines) — agent may need context escalation
```

---

## Error Handling

| Error | Action |
|-------|--------|
| Story file not found | Report `(x) File not found at [path]` and exit BLOCKED |
| No frontmatter block | Report `(x) V1: No YAML frontmatter detected` and continue remaining rules where possible |
| State file not found (V4) | Report `(!) V4: Cannot read state — .maestro/state.md not found; dependency check skipped` |
| CLAUDE.md parse error (V7) | Report `(!) V7: CLAUDE.md could not be parsed — manual review recommended` |
| Empty Files section (V3) | Report `(ok) V3: No file paths listed` — not a failure, just informational |

---

## Example Invocation

```
/story-validator .maestro/stories/03-api-routes.md
```

Strict mode (warnings block dispatch):
```
/story-validator .maestro/stories/03-api-routes.md --strict
```
