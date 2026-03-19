---
name: btw
description: "Ask a side question without disrupting the active orchestration session. Dispatches a lightweight Haiku agent and shows the answer inline."
argument-hint: "QUESTION"
allowed-tools:
  - Read
  - Glob
  - Skill
---

# Maestro BTW

**ALWAYS display this ASCII banner as the FIRST thing in your response, before any other output:**

```
██████╗ ████████╗██╗    ██╗
██╔══██╗╚══██╔══╝██║    ██║
██████╔╝   ██║   ██║ █╗ ██║
██╔══██╗   ██║   ██║███╗██║
██████╔╝   ██║   ╚███╔███╔╝
╚═════╝    ╚═╝    ╚══╝╚══╝
```

A side-question command. Ask anything without affecting the current session state, notes, or orchestration context. The answer is shown inline and immediately discarded — nothing is persisted.

## Step 1: Guard — No Arguments

If `$ARGUMENTS` is empty:

```
[btw] Usage: /maestro btw "your question here"

  Example:
    /maestro btw "What's the Next.js convention for API routes?"
    /maestro btw "What does RFC 9110 say about 409 vs 422?"
    /maestro btw "What's the difference between useEffect and useLayoutEffect?"

  Note: Answers are shown inline and NOT saved to session state.
```

Stop here.

## Step 2: Check for Active Session (Optional Context)

Read `.maestro/state.local.md` silently to determine if there is an active orchestration session. This is informational only — it does not block the question.

If an active session is found, note the current story or phase internally. Do NOT include session state in the Haiku prompt — the answer must be stateless and generic.

## Step 3: Dispatch Lightweight Answer Agent

Invoke the side-question skill:

```
Skill("side-question", "$ARGUMENTS")
```

The skill dispatches a Haiku agent with the question and returns a concise answer. The entire exchange happens in an isolated, ephemeral context.

## Step 4: Display Answer Inline

Show the answer using this format:

```
+---------------------------------------------+
| btw                                         |
+---------------------------------------------+

  Q: [QUESTION]

  [ANSWER — rendered as plain text or minimal markdown]

  (i) This answer was not saved to session state.
```

If the active session is paused mid-story, append:

```
  (i) Your active session is unaffected. Resuming where you left off.
```

## Step 5: Return to Previous Context

Do NOT:
- Write to `notes.md`
- Update `.maestro/state.local.md`
- Log to `.maestro/token-ledger.md`
- Modify any session or story state

The orchestration session (if active) continues exactly where it was before `/btw` was invoked.

## Error Handling

| Error | Action |
|-------|--------|
| Haiku agent unavailable | Fall back to answering inline directly without dispatching |
| Question is ambiguous | Answer the most reasonable interpretation; note the ambiguity |
| Question requires project context | Note that `/btw` is stateless — suggest `/maestro brain` if project context is needed |

## Output Contract

```yaml
output_contract:
  display:
    format: "box-drawing"
    sections:
      - "btw header"
      - "Q: [question]"
      - "Answer body"
      - "Informational footer"
  side_effects: none
  state_mutations: none
  session_impact: none
```
