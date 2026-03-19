---
name: pair-programming
description: "Verification-first human-AI collaboration mode. AI proposes diffs with test-first approach, human approves or modifies each step. Activated via /maestro pair or dev-loop mode: careful. Human can take over at any point."
---

# Pair Programming

A synchronous collaboration mode where human and AI work on the same code together. The AI acts as a co-pilot: proposing changes, writing tests first, and waiting for human approval at each step. The human is always the pilot and can take over at any point.

## Activation

```
/maestro pair                    # Start a pair session explicitly
/maestro pair --file src/auth.ts # Pair on a specific file
```

Also activates automatically when dev-loop mode is `careful` — all story phases run in pair mode, with the human seeing every proposed change before it is applied.

## Collaboration Contract

- AI proposes one change at a time.
- Human approves, modifies, or takes over before any change is applied.
- AI never applies changes without explicit approval.
- Human can issue `let me do this` at any point — AI steps back and observes.
- Human edits are fed back into the AI's context as corrections.

## Workflow

### Step 1: Frame the Intent

AI states what it is about to do and why, in plain language.

```
Intent: Add input validation to createUser route.
Reason: The handler currently trusts raw req.body — any shape is accepted.
Plan:
  1. Write a failing test for the validation behavior.
  2. Add Zod schema to validate the request body.
  3. Return 400 with structured error on schema failure.
Proceed? [yes / no / let me do this]
```

Use AskUserQuestion here:
- Question: "Ready to proceed with: [intent]?"
- Header: "Pair Programming"
- Options: Proceed / Modify plan / Let me do this

### Step 2: Write the Test First

Before any implementation, AI writes the test that captures the intended behavior.

Show the test as a diff preview:

```diff
// src/routes/users.test.ts

+  it("returns 400 when email is missing", async () => {
+    const res = await request(app)
+      .post("/users")
+      .send({ name: "Alice" });           // no email
+    expect(res.status).toBe(400);
+    expect(res.body.error).toMatch(/email/);
+  });
```

Use AskUserQuestion:
- Question: "Test written. Does this test correctly capture the intended behavior?"
- Header: "Pair Programming — Test Review"
- Options: Apply test / Modify test / Skip test / Let me write this

Human can modify the test inline. AI applies the human's version, not its own.

### Step 3: Run the Test (Red)

AI runs the test. It must fail.

```
Running test...

FAIL src/routes/users.test.ts
  x returns 400 when email is missing
    Expected: 400
    Received: 201

(ok) Test is red — behavior not yet implemented.
```

If the test passes unexpectedly, AI flags it:
```
Warning: test passed before implementation. This means either:
  1. The behavior already exists (no implementation needed), or
  2. The test is too weak and is not capturing the intended gap.

Review options: [view existing behavior] [strengthen test] [accept as-is]
```

### Step 4: Propose the Implementation

AI proposes the minimal change to make the test pass.

Show as a diff with full file context:

```diff
// src/routes/users.ts

+import { z } from "zod";
+
+const CreateUserSchema = z.object({
+  name: z.string().min(1),
+  email: z.string().email(),
+});

  router.post("/users", async (req, res) => {
-   const { name, email } = req.body;
+   const result = CreateUserSchema.safeParse(req.body);
+   if (!result.success) {
+     return res.status(400).json({ error: result.error.message });
+   }
+   const { name, email } = result.data;
    // ...
  });
```

Use AskUserQuestion:
- Question: "Implementation ready. Apply this change?"
- Header: "Pair Programming — Diff Review"
- Options: Apply / Modify / Reject / Let me implement this

Human can:
- **Apply** — AI writes the change as shown.
- **Modify** — Human provides a diff or instructions. AI applies the human's version.
- **Reject** — AI discards the proposal and re-plans.
- **Let me implement this** — AI steps back. Human edits directly. AI observes.

### Step 5: Run the Test (Green)

AI runs the test after applying the implementation.

```
Running test...

PASS src/routes/users.test.ts
  (ok) returns 400 when email is missing

Implementation is green.
```

If the test still fails after implementation, AI treats it as a self-heal loop (up to 3 attempts) and shows each attempt before applying.

### Step 6: Refactor

AI checks for cleanup opportunities and proposes any refactors explicitly. Refactors are subject to the same diff-review cycle.

If no refactor is needed:
```
No refactor needed. Code is clean.
```

### Step 7: Commit Checkpoint

After each logical unit of work (a test + implementation cycle), AI proposes a commit:

```
Proposed commit:
  feat(users): add Zod validation to createUser route

  - Validates name (string, min 1) and email (valid format)
  - Returns 400 with structured error on invalid input
  - Test: "returns 400 when email is missing"

Commit? [yes / amend message / skip]
```

## Human Takeover

At any point, the human can say:
- `let me do this` — AI steps aside. Human edits directly.
- `I've made my changes` — AI reads the updated files, diffs against last known state, and continues from that state.

When the human returns control:

```
Reading your changes...

You modified: src/routes/users.ts
Changes detected:
  + Added rate limiting middleware
  + Refactored error handler to use shared format

Incorporating your changes into my context.
Continue from here? [yes / re-plan / end session]
```

## Learning from Human Corrections

Every time the human modifies an AI proposal, the correction is fed into the learning loop:

```
Human correction detected: [description of what changed]
Recording as learning signal (source: pair_correction)
```

Corrections are written to `.maestro/notes.md` with `intent: feedback` so the learning-loop picks them up at the next milestone.

High-frequency corrections (same pattern 2+ times in a session) trigger an immediate memory entry:

```
memory.remember(
  "Human prefers X over Y in [context]",
  tier="lesson",
  confidence=0.90,
  source="pair_correction"
)
```

## File State Synchronization

Both human and AI operate on the same file state. Before each proposal:

1. AI reads the current file from disk (not from memory of a prior read).
2. AI diffs the current state against the proposed change.
3. If the file changed since the last read (human edited externally), AI re-reads and adjusts.

```
Note: File changed since last read. Re-reading and adjusting proposal.
```

## Session Controls

| Command | Action |
|---------|--------|
| `let me do this` | AI steps back, observes human edits |
| `I've made my changes` | AI re-reads files, resumes from current state |
| `/maestro pair --pause` | Pause session, save state |
| `/maestro pair --resume` | Resume from saved state |
| `/maestro pair --end` | End session, run learning loop |
| `/maestro pair --yolo` | Switch to autonomous mode for remaining work |

## Output Format

Every proposal follows the same structure to keep the interaction predictable:

```
Pair Programming — [intent label]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Context: [file:line range being modified]

[diff block]

What this does: [one sentence]
Why this way: [one sentence rationale]

[AskUserQuestion prompt]
```

## Integration Points

| Skill | Integration |
|-------|-------------|
| **dev-loop** | Mode `careful` activates pair mode for each phase. Phase 2 (DELEGATE) still runs normally; Phase 3 (IMPLEMENT) pauses for AI proposals. |
| **learning-loop** | Human corrections from pair sessions are injected as `pair_correction` signals in RETRIEVE. |
| **memory** | Corrections that trigger immediate memory entry use `memory.remember()` with `source: pair_correction`. |
| **git-craft** | Commit checkpoint at Step 7 uses git-craft for documentation-quality commit messages. |
| **self-correct** | If AI makes the same mistake twice in a session, self-correct activates and the pair session pauses to surface the pattern. |
