---
name: memory
description: "Session memory with salience-weighted persistence and confidence scoring. Tracks semantic facts (long-term) and episodic context (decays between sessions). Inspired by ClaudeClaw's dual-sector memory and claude-reflect's confidence scoring."
---

# Maestro Memory

Markdown-based dual-sector memory that persists project knowledge between sessions. Semantic memory stores long-term facts. Episodic memory stores session context with salience decay. Every entry carries a confidence score (0.0-1.0) that reflects reliability and is used to weight retrieval.

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
- [date] [0.95] Prefers Sonnet for all execution tasks (cost reason)
- [date] [0.70] Likes terse commit messages — inferred from corrections
- [date] [1.00] Never use default exports in this project
- [date] [1.00] Always run tests before committing

## Architecture Decisions
- [date] [1.00] JWT with 15min expiry, refresh tokens in httpOnly cookies
- [date] [0.90] Supabase Auth chosen over Auth0 for cost and integration
- [date] [0.70] Rate limiting: 10 req/min on public endpoints

## Quality Rules
- [date] [1.00] Always check for null relations before accessing nested properties
- [date] [1.00] Test files must follow *.test.ts naming (not *.spec.ts)

## Project Context
- [date] [1.00] Main branch is "develop", not "main"
- [date] [0.90] CI runs on GitHub Actions, must pass before merge
```

### Episodic Memory (`.maestro/memory/episodic.md`)

Session-specific context with salience decay. Each entry has a salience score that decreases between sessions and a confidence score that reflects how reliable the captured information is.

**Format:**

```markdown
# Episodic Memory

## Entries

### [salience: 1.0] [confidence: 0.90] [date] [session_id]
Working on user authentication feature. 5 stories decomposed.
Auth middleware uses passport.js with local strategy.

### [salience: 0.8] [confidence: 0.70] [date] [session_id]
Fixed rate limiting bug. Was applying per-route instead of per-IP.
Solution: moved rate limiter to Express middleware chain.

### [salience: 0.64] [confidence: 0.50] [date] [session_id]
Refactored API routes to use router groups. Reduced boilerplate.
Pattern: router.use('/api/v1', authRouter, userRouter, etc.)
```

## Confidence Scoring

Every memory entry carries a confidence score (0.0-1.0) reflecting how reliable the information is. Confidence is assigned at creation time and updated as evidence accumulates.

### Confidence Assignment Rules

| Score | Meaning | Example trigger |
|-------|---------|----------------|
| 1.0 | Explicit user statement | "always use X", "never do Y", "remember that Z" |
| 0.9 | Confirmed by multiple successful executions | Pattern worked in 3+ sessions without correction |
| 0.7 | Inferred from single successful execution | Approach worked once, no correction received |
| 0.5 | Inferred from context | Reasonable assumption, unconfirmed |
| 0.3 | Contradicted once but not explicitly overridden | User accepted workaround but didn't endorse pattern |
| 0.0 | Explicitly contradicted by user | Mark for immediate removal |

**Signal-to-confidence mapping in `detect_semantic_signals()`:**

- "always ..." / "never ..." / "from now on ..." / "remember that ..." → 1.0
- "I prefer ..." / "we prefer ..." → 0.9
- "use X instead of Y" / "no, not X — use Y" → 0.9 (correction confirms new pattern)
- "don't do X" / "stop doing X" → 0.9
- Successful execution without feedback → 0.7
- Context inference (no explicit signal) → 0.5

### Confidence Decay Rules

**Semantic memories** — confidence decays between sessions if not reinforced:
- Each session without reinforcement: confidence -= 0.05
- Reinforcement (entry referenced or confirmed): confidence restored to min(current + 0.1, original)
- Minimum threshold: **0.2** — entries below this are flagged for cleanup

**Episodic memories** — confidence decays alongside salience:
- Confidence tracks salience decay (both decay together)
- When salience drops below 0.1, entry is pruned regardless of confidence
- Entries with confidence < 0.2 are flagged for cleanup even if salience is still high

### Confidence-Based Retrieval

When composing context via `build_context()`, weight memories by confidence score:

| Band | Range | Retrieval rule |
|------|-------|---------------|
| High | > 0.7 | Always included in context |
| Medium | 0.4-0.7 | Included if relevant to the current task |
| Low | < 0.4 | Only included if directly queried |

Entries at 0.0 (explicitly contradicted) are never retrieved and are removed on the next maintenance pass.

## Operations

### initialize()

Called at the start of each Maestro session.

1. Create `.maestro/memory/` directory if it doesn't exist
2. Create `semantic.md` and `episodic.md` if they don't exist
3. Run decay sweep on episodic memory
4. Apply per-session confidence decay to semantic memory (confidence -= 0.05 for unreinforced entries)
5. Flag entries below confidence threshold 0.2 for maintenance

### decay_sweep()

Apply salience decay to all episodic entries:

1. Read `.maestro/memory/episodic.md`
2. For each entry:
   - Multiply salience by 0.8 (20% decay per session)
   - Apply matching confidence decay (multiply confidence by 0.8)
   - If salience < 0.1 OR confidence < 0.2, remove the entry
3. Write updated file

This means:
- After 1 session: salience 0.8
- After 2 sessions: salience 0.64
- After 3 sessions: salience 0.512
- After 5 sessions: salience 0.328
- After 10 sessions: salience 0.107
- After 11 sessions: salience 0.086 → pruned

Entries survive approximately 10 sessions before being pruned.

### save_semantic(fact, category, confidence)

Add a long-term fact to semantic memory.

1. Read current `semantic.md`
2. Check for contradictions (similar topic, different conclusion)
   - If found, replace the old entry with the new one
   - Set confidence of new entry as provided (or 0.5 if not specified)
3. Add new entry under the appropriate category with today's date and confidence score
4. Write updated file

### save_episodic(context, session_id, confidence)

Add session context to episodic memory.

1. Read current `episodic.md`
2. Add new entry at the top with salience 1.0, confidence as provided (default 0.7), current date, and session_id
3. Write updated file

### build_context()

Build a context block from memory for injection into agent prompts.

1. Read `semantic.md`:
   - Always include entries with confidence > 0.7
   - Include entries with confidence 0.4-0.7 if relevant to current task
   - Omit entries with confidence < 0.4 unless directly queried
2. Read `episodic.md` — include entries with salience >= 0.3 AND confidence >= 0.4 (top 5 max)
3. Format as a context block:

```
[Project Memory]

Semantic (long-term):
- [1.00] Prefers Sonnet for execution (cost reason)
- [1.00] JWT auth with 15min expiry, refresh in cookies
- [1.00] Never use default exports
- [1.00] Always check null relations before nested access

Recent context (episodic):
- [sal:0.80 conf:0.90] Working on user auth, 5 stories, passport.js local strategy
- [sal:0.64 conf:0.70] Fixed rate limiting: moved to Express middleware chain

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
3. Assign confidence per the confidence assignment rules above
4. Call `save_semantic(fact, category, confidence)`

### reinforce(entry_id)

When an episodic memory is referenced during a session (search match or context injection), boost its salience and confidence:

```
new_salience = min(salience + 0.2, 2.0)
new_confidence = min(confidence + 0.1, original_confidence)
```

When a semantic memory is confirmed by user feedback or successful execution:
```
new_confidence = min(confidence + 0.1, 1.0)
```

This keeps frequently-relevant, high-confidence memories alive longer.

### memory_maintenance()

Run after each session to keep memory files clean and trustworthy.

1. Scan `semantic.md` for entries with confidence < 0.2
2. Scan `episodic.md` for entries with confidence < 0.2 or salience < 0.1
3. For each flagged entry, propose one of:
   - **Remove** — confidence has decayed below threshold, no reinforcement received
   - **Archive** — important historical context; move to `.maestro/memory/archive.md`
   - **Reinforce** — user confirms entry is still valid; restore confidence to 0.5
4. Log maintenance actions at the bottom of each memory file:

```markdown
## Maintenance Log
- [date] Removed: "Rate limiting: 10 req/min" (confidence decayed to 0.15, unreinforced for 6 sessions)
- [date] Archived: "Refactored API routes" (episodic entry, salience 0.08)
- [date] Reinforced: "Prefers Sonnet for execution" (user confirmed, confidence 0.70 → 0.80)
```

## Memory Maintenance

After each session, scan memory files and act on low-confidence entries to keep memory trustworthy.

### When to Run

Call `memory_maintenance()` at the end of every session, after episodic context has been saved.

### Maintenance Steps

1. Scan `semantic.md` for entries with confidence < 0.2
2. Scan `episodic.md` for entries with confidence < 0.2 or salience < 0.1
3. For each flagged entry, choose an action:
   - **Remove** — confidence decayed below threshold with no reinforcement; delete from file
   - **Archive** — historically significant; move to `.maestro/memory/archive.md` for reference
   - **Reinforce** — user confirms the entry is still valid; restore confidence to 0.5
4. Log all actions in the Maintenance Log section of the relevant file

### Maintenance Log Format

Append to the bottom of `semantic.md` or `episodic.md`:

```markdown
## Maintenance Log
- [date] Removed: "Rate limiting: 10 req/min" (confidence decayed to 0.15, unreinforced for 6 sessions)
- [date] Archived: "Refactored API routes" (episodic entry, salience 0.08)
- [date] Reinforced: "Prefers Sonnet for execution" (user confirmed, confidence 0.70 → 0.80)
```

### Maintenance Principles

- Prefer **remove** for low-signal entries (confidence was never high, decayed fast)
- Prefer **archive** for entries that were once high-confidence and may resurface
- Never silently delete entries — always log the action
- Propose removals to the user if uncertain; do not auto-delete without logging

## PostCompact Hook Integration

The `PostCompact` hook (Claude Code v2.1.76) fires after context compaction. This is critical for memory — without it, the agent loses awareness of previously loaded memory after compaction.

### How It Works

When context is compacted:
1. The `post-compact-hook.sh` fires and reads current session state
2. It outputs a `systemMessage` containing:
   - Current feature, mode, phase, story progress
   - North Star from `.maestro/vision.md`
   - Recent notes from `.maestro/notes.md`
3. This message is injected into the post-compaction context

### Memory Re-injection After Compaction

The PostCompact hook handles basic state re-injection. For full memory re-injection:

1. The `PostCompact` hook provides the session state anchor
2. On the NEXT `build_context()` call, the memory skill re-reads both memory files
3. High-confidence entries (> 0.7) are always re-injected
4. This ensures the agent regains project knowledge within 1 turn after compaction

### Plugin Data Migration

When `${CLAUDE_PLUGIN_DATA}` is available (Claude Code v2.1.78+), memory operations should prefer this durable store over file-based persistence for frequently-accessed metadata like:
- Current session confidence thresholds
- Decay counters (number of sessions since last reinforcement per entry)
- Maintenance log summaries

The full memory files (semantic.md, episodic.md) remain as markdown files for git tracking and human readability. `${CLAUDE_PLUGIN_DATA}` supplements them with operational metadata.

## Integration Points

### In Dev-Loop

At session start:
```
memory.initialize()  # creates files, runs decay, applies confidence decay
context = memory.build_context()  # confidence-weighted context for context engine
```

At each CHECKPOINT:
```
memory.save_episodic(story_summary, session_id, confidence=0.70)
```

When user provides corrections or feedback:
```
memory.detect_semantic_signals(user_message, assistant_response)
```

At session end:
```
memory.memory_maintenance()  # scan below-threshold entries, log actions
```

### In Context Engine

When composing agent context:
```
memory_context = memory.build_context()
inject memory_context into agent prompt
# high-confidence entries always included; medium/low weighted by task relevance
```

### In Retrospective

After generating improvement proposals:
```
for each approved improvement:
    memory.save_semantic(improvement, "quality_rule", confidence=0.90)
```

## File Management

- Memory files are committed to git (they're project-specific knowledge)
- They should be in `.maestro/memory/` which is tracked
- Session-specific state (state.local.md) is gitignored, but memory is not
- This means memory persists across branches and collaborators
- Archive file (`.maestro/memory/archive.md`) is also committed — it preserves historical context without polluting active retrieval

## Limits

- Semantic memory: no limit (entries are curated and concise)
- Episodic memory: max 20 entries (oldest/lowest salience pruned first)
- Context injection: max 500 tokens from memory (to stay within budget)
- Confidence threshold for active retrieval: 0.2 (below this, flag for maintenance)
