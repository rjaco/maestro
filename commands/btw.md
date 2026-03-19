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

---

## Argument Parsing

`$ARGUMENTS` is the full question text. It may be quoted or unquoted:

- `/maestro btw "What is the difference between null and undefined?"` — quoted
- `/maestro btw What is the difference between null and undefined?` — unquoted (both work)

Strip outer quotes if present. The entire argument string (after stripping quotes) is the question.

If `$ARGUMENTS` is empty or whitespace-only, show the usage message and stop — do not dispatch a skill.

**Maximum question length:** 500 characters. If longer, truncate to 500 and append `(i) Question truncated to 500 characters.`

## Answer Length and Formatting

The answer should be:
- **Concise** — 1–5 sentences for simple factual questions
- **Structured** — use a short bullet list when the question asks "what are the differences" or "what are the options"
- **Code-bearing** — include a brief code snippet if the question is about syntax or an API

The answer must NOT:
- Reference the current session, story, or project
- Use headers (`##`, `###`)
- Exceed ~300 words

If the question is long or multi-part, answer the most important part first, then add a note: `(i) This is a complex question — for full depth, consider opening a focused conversation.`

## Context Awareness (Read-Only)

When Step 2 detects an active session (state file exists with `active: true`), the command may silently use the current language, framework, or stack preferences to improve answer relevance — but must NOT expose or reference session-specific details in the output.

**Allowed:** Using `TypeScript` context to frame a language-specific answer.
**Not allowed:** Mentioning story names, milestone numbers, or in-progress work.

## Examples

### Example 1: Quick factual question

```
/maestro btw "What's the Next.js convention for API routes?"
```

```
██████╗ ████████╗██╗    ██╗
...

+---------------------------------------------+
| btw                                         |
+---------------------------------------------+

  Q: What's the Next.js convention for API routes?

  In the App Router, API routes are defined as `route.ts` files inside
  `app/` directories. For example: `app/api/users/route.ts` exports
  named functions `GET`, `POST`, `PUT`, `DELETE`, etc.

  In the Pages Router (legacy), API routes live in `pages/api/` and
  export a default handler function.

  (i) This answer was not saved to session state.
  (i) Your active session is unaffected. Resuming where you left off.
```

### Example 2: Question requiring a code snippet

```
/maestro btw "How do I type a React ref for a div element?"
```

```
+---------------------------------------------+
| btw                                         |
+---------------------------------------------+

  Q: How do I type a React ref for a div element?

  Use `useRef<HTMLDivElement>(null)`:

  ```typescript
  const ref = useRef<HTMLDivElement>(null);
  ```

  Access the DOM node via `ref.current` (it will be `null` until the
  component mounts, so check `if (ref.current)` before use).

  (i) This answer was not saved to session state.
```

### Example 3: Missing question

```
/maestro btw
```

```
[btw] Usage: /maestro btw "your question here"

  Example:
    /maestro btw "What's the Next.js convention for API routes?"
    /maestro btw "What does RFC 9110 say about 409 vs 422?"
    /maestro btw "What's the difference between useEffect and useLayoutEffect?"

  Note: Answers are shown inline and NOT saved to session state.
```

### Example 4: Project-context question redirected

```
/maestro btw "What are the current stories in this project?"
```

```
+---------------------------------------------+
| btw                                         |
+---------------------------------------------+

  Q: What are the current stories in this project?

  /maestro btw is stateless — it cannot access your project's stories
  or session history.

  For project-specific context, use:
    /maestro status      — current session and story progress
    /maestro brain       — search project knowledge base
    /maestro stories     — list all stories

  (i) This answer was not saved to session state.
```
