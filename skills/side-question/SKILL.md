---
name: side-question
description: "Answer a one-off question using a lightweight Haiku agent. Stateless — no session context read or written. Called by the /btw command."
effort: minimal
maxTurns: 1
disallowedTools:
  - Write
  - Edit
  - Bash
  - Glob
---

# Side-Question

Answers a single, isolated question without reading or mutating any session state. This skill is designed to be ephemeral: it fires a Haiku agent, returns the answer, and leaves no trace.

## Design Constraints

- **Stateless** — does not read `.maestro/state.local.md`, `notes.md`, or any project file.
- **Ephemeral** — output is displayed inline only; nothing is written to disk.
- **Lightweight** — always uses Haiku. Never escalates to Sonnet or Opus.
- **Single-turn** — `maxTurns: 1`. One question, one answer, done.
- **No token ledger** — this invocation is intentionally excluded from cost tracking.

## Input

`$ARGUMENTS` — the raw question string from the user.

## Process

### Step 1: Validate Input

If `$ARGUMENTS` is empty or fewer than 3 words, return:

```
[side-question] No question received.
```

### Step 2: Compose the Haiku Prompt

Build a minimal, focused prompt. Do NOT inject project context, session state, or file contents.

```
You are a concise technical assistant. Answer the following question directly and accurately.
Keep your answer short: aim for 3-8 sentences or a brief code snippet when code helps.
Do not add preamble, caveats, or ask follow-up questions.

Question: [QUESTION]
```

### Step 3: Dispatch Haiku Agent

```
Agent(
  subagent_type: "claude-haiku",
  description: "btw: [QUESTION truncated to 60 chars]",
  run_in_background: false,
  model: "haiku",
  prompt: "[composed prompt]"
)
```

**Key dispatch properties:**
- `run_in_background: false` — answer is needed synchronously before returning to the caller
- `model: haiku` — always Haiku, no escalation
- No `isolation` — no worktree needed (no file writes)
- No session context passed in prompt

### Step 4: Return Answer

Return the raw agent response to the `/btw` command for inline display.

If the agent returns an empty response or errors:

```
[side-question] Could not get an answer. Try rephrasing your question.
```

## What This Skill Does NOT Do

- Does not read any project files
- Does not update token-ledger
- Does not write to notes.md or state
- Does not trigger delegation, QA, or any other orchestration skill
- Does not persist context for future turns

## Integration

- Called exclusively by `commands/btw.md`
- Answer is displayed by the `/btw` command, not by this skill directly
- Token spend from this skill is intentionally untracked (side questions are noise in cost analysis)

## Output Contract

```yaml
output_contract:
  returns: "plain text answer string"
  side_effects: none
  state_mutations: none
  token_ledger: excluded
```
