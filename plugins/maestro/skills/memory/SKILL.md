---
name: memory
description: "Session memory with salience-weighted persistence. Tracks semantic facts (long-term) and episodic context (decays between sessions). Inspired by ClaudeClaw's dual-sector memory."
---

# Maestro Memory

Markdown-based dual-sector memory that persists project knowledge between sessions. Semantic memory stores long-term facts. Episodic memory stores session context with salience decay.

## Architecture

Two markdown files in `.maestro/memory/`:

### Semantic Memory (`.maestro/memory/semantic.md`)

Long-term facts about the project and user preferences. These persist indefinitely and are only updated when contradicted by newer information.

**Sources:**
- User corrections during dev-loop ("no, use X instead of Y")
- Explicit preference statements ("always use...", "never do...")
- Architecture decisions captured from retrospectives
- Quality rules learned from QA rejections

**Format:**

```markdown
# Semantic Memory

## User Preferences
- [date] Prefers Sonnet for all execution tasks (cost reason)
- [date] Never use default exports in this project
- [date] Always run tests before committing

## Architecture Decisions
- [date] JWT with 15min expiry, refresh tokens in httpOnly cookies
- [date] Supabase Auth chosen over Auth0 for cost and integration
- [date] Rate limiting: 10 req/min on public endpoints

## Quality Rules
- [date] Always check for null relations before accessing nested properties
- [date] Test files must follow *.test.ts naming (not *.spec.ts)

## Project Context
- [date] Main branch is "develop", not "main"
- [date] CI runs on GitHub Actions, must pass before merge
```

### Episodic Memory (`.maestro/memory/episodic.md`)

Session-specific context with salience decay. Each entry has a score that decreases between sessions.

**Format:**

```markdown
# Episodic Memory

## Entries

### [salience: 1.0] [date] [session_id]
Working on user authentication feature. 5 stories decomposed.
Auth middleware uses passport.js with local strategy.

### [salience: 0.8] [date] [session_id]
Fixed rate limiting bug. Was applying per-route instead of per-IP.
Solution: moved rate limiter to Express middleware chain.

### [salience: 0.64] [date] [session_id]
Refactored API routes to use router groups. Reduced boilerplate.
Pattern: router.use('/api/v1', authRouter, userRouter, etc.)
```

## Operations

### initialize()

Called at the start of each Maestro session.

1. Create `.maestro/memory/` directory if it doesn't exist
2. Create `semantic.md` and `episodic.md` if they don't exist
3. Run decay sweep on episodic memory

### decay_sweep()

Apply salience decay to all episodic entries:

1. Read `.maestro/memory/episodic.md`
2. For each entry:
   - Multiply salience by 0.8 (20% decay per session)
   - If salience < 0.1, remove the entry
3. Write updated file

This means:
- After 1 session: 0.8
- After 2 sessions: 0.64
- After 3 sessions: 0.512
- After 5 sessions: 0.328
- After 10 sessions: 0.107
- After 11 sessions: 0.086 → pruned

Entries survive approximately 10 sessions before being pruned.

### save_semantic(fact, category)

Add a long-term fact to semantic memory.

1. Read current `semantic.md`
2. Check for contradictions (similar topic, different conclusion)
   - If found, replace the old entry with the new one
3. Add new entry under the appropriate category with today's date
4. Write updated file

### save_episodic(context, session_id)

Add session context to episodic memory.

1. Read current `episodic.md`
2. Add new entry at the top with salience 1.0, current date, and session_id
3. Write updated file

### build_context()

Build a context block from memory for injection into agent prompts.

1. Read `semantic.md` — include ALL entries (they're all relevant long-term)
2. Read `episodic.md` — include entries with salience >= 0.3 (top 5 max)
3. Format as a context block:

```
[Project Memory]

Semantic (long-term):
- Prefers Sonnet for execution (cost reason)
- JWT auth with 15min expiry, refresh in cookies
- Never use default exports
- Always check null relations before nested access

Recent context (episodic):
- [0.80] Working on user auth, 5 stories, passport.js local strategy
- [0.64] Fixed rate limiting: moved to Express middleware chain

[End Project Memory]
```

4. Return this block for injection by the context engine.

### detect_semantic_signals(user_message, assistant_response)

Check if a conversation turn contains information worth saving as semantic memory.

**Semantic signals** (patterns in user messages):
- "always ..." / "never ..."
- "I prefer ..." / "we prefer ..."
- "use X instead of Y"
- "don't do X" / "stop doing X"
- "remember that ..."
- "from now on ..."
- Corrections: "no, not X — use Y"

If a signal is detected:
1. Extract the fact
2. Categorize: user_preference | architecture_decision | quality_rule | project_context
3. Call `save_semantic(fact, category)`

### reinforce(entry_id)

When an episodic memory is referenced during a session (search match or context injection), boost its salience:

```
new_salience = min(salience + 0.2, 2.0)
```

This keeps frequently-relevant memories alive longer.

## Integration Points

### In Dev-Loop

At session start:
```
memory.initialize()  # creates files, runs decay
context = memory.build_context()  # for context engine
```

At each CHECKPOINT:
```
memory.save_episodic(story_summary, session_id)
```

When user provides corrections or feedback:
```
memory.detect_semantic_signals(user_message, assistant_response)
```

### In Context Engine

When composing agent context:
```
memory_context = memory.build_context()
inject memory_context into agent prompt
```

### In Retrospective

After generating improvement proposals:
```
for each approved improvement:
    memory.save_semantic(improvement, "quality_rule")
```

## File Management

- Memory files are committed to git (they're project-specific knowledge)
- They should be in `.maestro/memory/` which is tracked
- Session-specific state (state.local.md) is gitignored, but memory is not
- This means memory persists across branches and collaborators

## Limits

- Semantic memory: no limit (entries are curated and concise)
- Episodic memory: max 20 entries (oldest/lowest salience pruned first)
- Context injection: max 500 tokens from memory (to stay within budget)
