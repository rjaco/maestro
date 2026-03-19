---
name: memory
description: "Three-tier durable memory with semantic search, structured YAML entries, confidence scoring, and automatic decay. Facts persist permanently, Lessons decay slowly, Episodes decay between sessions. Supports keyword search, tier promotion, and Context Engine injection."
---

# Maestro Memory

Three-tier memory system that persists project knowledge between sessions using structured YAML blocks in markdown files. Every entry carries a confidence score (0.0-1.0) that decays over time based on tier. Entries are searchable by keyword and category tag. High-confidence entries are injected into agent context automatically.

## Architecture

All memory lives in `.maestro/memory/`:

```
.maestro/memory/
  memories.md          # active memory — all three tiers in one file
  archived.md          # entries that fell below confidence threshold
```

The single-file design keeps the full memory set readable by agents in one read.

### Memory Tiers

| Tier | Decay per session | Archive threshold | Promotion |
|------|------------------|-------------------|-----------|
| `fact` | none | never | manual only (user confirms) |
| `lesson` | -0.05 confidence | < 0.30 | auto when lesson confirmed by user |
| `episode` | -0.20 confidence | < 0.30 | auto when access_count >= 5 |

### Memory Entry Format

All entries use YAML blocks fenced with `~~~yaml` inside the markdown file so they are both machine-parseable and human-readable:

```yaml
- id: mem_001
  content: "API routes in this project always use Zod safeParse, never parse"
  category: coding_pattern
  tier: lesson
  confidence: 0.90
  created: "2026-03-17"
  last_accessed: "2026-03-18"
  access_count: 7
  source: "QA feedback on stories M1-03, M2-01, M2-04"
  tags: [api, validation, zod]
```

**Field definitions:**

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique identifier, format `mem_NNN` (zero-padded, auto-incremented) |
| `content` | string | The memory itself — a single concrete, actionable statement |
| `category` | string | One of: `coding_pattern`, `user_preference`, `architecture_decision`, `quality_rule`, `project_context`, `workflow`, `incident` |
| `tier` | string | `fact`, `lesson`, or `episode` |
| `confidence` | float | 0.0–1.0. Assigned at creation; decays per tier rules |
| `created` | date | ISO date string `YYYY-MM-DD` |
| `last_accessed` | date | Updated each time this entry is returned by `recall()` or injected into context |
| `access_count` | int | Incremented on every access; triggers episode→lesson promotion at 5 |
| `source` | string | Free-text provenance: where this memory came from |
| `tags` | list | Keyword tags for search; always lowercase |

### memories.md Layout

```markdown
# Maestro Memory

<!-- AUTO-MANAGED — do not edit YAML blocks by hand -->

## Facts

~~~yaml
- id: mem_001
  content: "Main branch is develop, not main"
  category: project_context
  tier: fact
  confidence: 1.0
  created: "2026-03-10"
  last_accessed: "2026-03-18"
  access_count: 14
  source: "User stated explicitly on project init"
  tags: [git, branch, workflow]
~~~

## Lessons

~~~yaml
- id: mem_003
  content: "Always use Zod safeParse, never parse — parse throws and we don't catch in route handlers"
  category: coding_pattern
  tier: lesson
  confidence: 0.90
  created: "2026-03-12"
  last_accessed: "2026-03-18"
  access_count: 9
  source: "QA rejection on M2-01"
  tags: [zod, validation, api, error-handling]
~~~

## Episodes

~~~yaml
- id: mem_007
  content: "Working on auth feature M3 — passport.js local strategy, 5 stories decomposed"
  category: project_context
  tier: episode
  confidence: 0.90
  created: "2026-03-18"
  last_accessed: "2026-03-18"
  access_count: 1
  source: "Session 2026-03-18"
  tags: [auth, passport, session-context]
~~~

## Maintenance Log

- [2026-03-18] Archived mem_002 (episode, confidence decayed to 0.10 after 4 sessions)
- [2026-03-18] Promoted mem_005: episode → lesson (access_count reached 5)
```

## Confidence Scoring

### Assignment at Creation

| Score | Trigger |
|-------|---------|
| 1.0 | Explicit user statement: "always", "never", "from now on", "remember that" |
| 0.9 | User correction confirming a new pattern: "use X, not Y" |
| 0.9 | Pattern confirmed by 3+ successful executions without pushback |
| 0.7 | Inferred from a single successful execution |
| 0.5 | Contextual inference — reasonable but unconfirmed |
| 0.3 | Contradicted once but not explicitly overridden |
| 0.0 | Explicitly contradicted — mark for immediate removal |

### Decay Rules

```
For each memory entry (run at session start — decay_cycle()):
  if tier == "fact":
    no change

  if tier == "lesson":
    confidence -= 0.05
    if confidence < 0.30:
      archive entry

  if tier == "episode":
    confidence -= 0.20
    if confidence < 0.30:
      archive entry

  if tier == "episode" AND access_count >= 5:
    promote to "lesson"
    reset confidence to max(confidence, 0.70)
```

### Reinforcement

When an entry is accessed (returned by `recall()` or injected into context):
- `last_accessed` = today
- `access_count` += 1
- `confidence` = min(confidence + 0.05, original_confidence_at_creation)

When a user explicitly confirms an entry ("yes, that's right", "keep that"):
- `confidence` = min(confidence + 0.15, 1.0)

When a lesson is explicitly confirmed by the user, it becomes a fact:
- `tier` = "fact"
- `confidence` = 1.0

### Retrieval Weighting

| Band | Range | Retrieval rule |
|------|-------|---------------|
| High | > 0.70 | Always included when relevant |
| Medium | 0.40–0.70 | Included when relevant to current task |
| Low | 0.30–0.40 | Only on direct query |
| Archived | < 0.30 | Moved to archived.md; excluded from retrieval |

## Operations

### remember \<content\>

Add a new memory entry.

**Signature:** `remember <content> [tier=lesson] [category=auto] [tags=auto]`

1. Detect tier from signal words in content (see signal detection below); default is `lesson`
2. Auto-assign category from content (coding pattern, preference, architectural, etc.)
3. Auto-extract tags (nouns and domain keywords from content)
4. Assign confidence per creation rules above
5. Generate next `id` (`mem_NNN`, incrementing from highest existing id)
6. Write entry to the appropriate section of `memories.md`
7. Return: `Saved mem_NNN (lesson, confidence 0.90)`

**Signal detection for tier:**
- "just now" / "today" / "this session" / "working on" → `episode`
- "always" / "never" / "from now on" / "remember that" / "prefer" → `fact` (confidence 1.0)
- Everything else → `lesson`

### recall \<query\>

Search memories by keyword and tag matching.

**Signature:** `recall <query>`

1. Tokenize query into keywords
2. For each active memory entry:
   - Score: count keyword matches in `content` + `tags` + `category`
   - Entries with score > 0 are candidates
3. Sort candidates by: score DESC, confidence DESC, last_accessed DESC
4. Update `last_accessed` and `access_count` for all returned entries
5. Apply promotion check after updating counts
6. Return top matches, formatted:

```
mem_003 [lesson, conf:0.90] "Always use Zod safeParse, never parse"
  tags: zod, validation, api | accessed: 2026-03-18 (9x)

mem_007 [episode, conf:0.90] "Working on auth feature M3 — passport.js..."
  tags: auth, passport, session-context | accessed: 2026-03-18 (1x)
```

If no matches: `No memories matched "<query>". Try broader keywords or run stats to browse by category.`

### forget \<id\>

Archive a specific memory by ID.

**Signature:** `forget <id>`

1. Find entry by `id` in `memories.md`
2. Move the YAML block to `archived.md` under an `## Archived` section
3. Add a Maintenance Log entry: `[date] Archived mem_NNN: user-requested forget`
4. Return: `Archived mem_NNN. To restore it, use promote mem_NNN.`

Note: `forget` archives, never hard-deletes. The archive preserves history for audit.

### promote \<id\>

Promote a memory to the next tier, or restore an archived memory.

**Signature:** `promote <id>`

**Episode → Lesson:**
1. Change `tier` to `lesson`
2. Set `confidence` to max(current_confidence, 0.70)
3. Move entry from `## Episodes` to `## Lessons` section
4. Log: `[date] Promoted mem_NNN: episode → lesson (manual)`

**Lesson → Fact:**
1. Confirm with user: "Promote mem_NNN to permanent fact? Facts never decay. (yes/no)"
2. On confirmation:
   - Change `tier` to `fact`
   - Set `confidence` to 1.0
   - Move entry to `## Facts` section
   - Log: `[date] Promoted mem_NNN: lesson → fact (user confirmed)`

**Archived → Active:**
1. Move entry from `archived.md` back to the appropriate section in `memories.md`
2. Restore `confidence` to 0.50 (minimum viable)
3. Log: `[date] Restored mem_NNN from archive`

### decay

Run the decay cycle manually (normally automatic at session start).

**Signature:** `decay`

1. Read all entries from `memories.md`
2. Apply tier-based decay rules to each entry
3. Archive entries that fell below 0.30
4. Apply auto-promotion for episodes with access_count >= 5
5. Write updated `memories.md`
6. Return summary:

```
Decay cycle complete:
  Facts:   5 entries — no change
  Lessons: 8 entries — 2 lost 0.05 confidence, 1 archived (mem_004)
  Episodes: 3 entries — 1 promoted to lesson (mem_009), 1 archived (mem_010)
```

### stats

Show memory health and overview.

**Signature:** `stats`

Returns:

```
Memory Stats — 2026-03-18
━━━━━━━━━━━━━━━━━━━━━━━━━
Facts:    5 entries | avg confidence: 1.00
Lessons: 11 entries | avg confidence: 0.78 | lowest: mem_006 (0.35)
Episodes: 3 entries | avg confidence: 0.83

Total active: 19 | Archived: 7

Most accessed: mem_001 (14x) — "Main branch is develop, not main"
Oldest active: mem_001 (created 2026-03-10)
Newest:        mem_012 (created 2026-03-18)
At-risk (conf < 0.40): mem_006 (lesson, 0.35), mem_008 (episode, 0.30)
```

## Decay Cycle (Session Lifecycle)

### decay_cycle() — runs at session start

```
1. Read memories.md
2. For each entry in Lessons:
     entry.confidence -= 0.05
     if entry.confidence < 0.30:
       archive(entry)
3. For each entry in Episodes:
     entry.confidence -= 0.20
     if entry.confidence < 0.30:
       archive(entry)
     if entry.access_count >= 5:
       promote_to_lesson(entry)
4. Write updated memories.md
5. Write archived entries to archived.md
6. Log all actions in Maintenance Log
```

### archive(entry)

1. Append entry YAML block to `archived.md` under `## Archived`
2. Add line to Maintenance Log: `[date] Archived <id> (<tier>, confidence <value>)`
3. Remove entry from `memories.md`

### promote_to_lesson(entry)

1. Move YAML block from `## Episodes` to `## Lessons`
2. Set `tier: lesson`
3. Set `confidence: max(entry.confidence, 0.70)`
4. Log: `[date] Promoted <id>: episode → lesson (access_count: <n>)`

## Signal Detection

### detect_signals(user_message)

Scan user messages for memory-worthy content:

**Tier signals:**
- "always" / "never" / "from now on" / "remember that" / "remember:" → `fact`, confidence 1.0
- "I prefer" / "we prefer" / "prefer to" → `fact`, confidence 0.9
- "use X instead of Y" / "no, not X" / "don't do X" / "stop doing X" → `lesson`, confidence 0.9
- "just for now" / "this session" → `episode`, confidence 0.7
- Corrections without explicit signals → `lesson`, confidence 0.7
- Architecture statements (implies permanence) → `lesson`, confidence 0.8

**Category signals:**
- Code syntax, library usage, patterns → `coding_pattern`
- "I prefer", "like", "dislike", "want" → `user_preference`
- "we decided", "architecture is", "using X for Y" → `architecture_decision`
- "always check", "never forget to", "rule:" → `quality_rule`
- Branch names, CI, deployment, team info → `project_context`
- "workflow", "process", "how we" → `workflow`
- "bug", "incident", "broke", "caused by" → `incident`

If a signal is detected:
1. Extract the fact as a clean, actionable statement
2. Determine tier and category
3. Call `remember(content, tier, category)`

## Context Engine Integration

### build_context()

Build a memory context block for injection into agent prompts. Target: max 500 tokens.

1. Read `memories.md`
2. Select entries:
   - All `fact` entries with confidence 1.0
   - `lesson` entries with confidence > 0.70 (always)
   - `lesson` entries with confidence 0.40–0.70 (if relevant to current task)
   - `episode` entries with confidence >= 0.50 (top 3 most recent)
3. Sort within each tier: confidence DESC, access_count DESC
4. Format output:

```
[Project Memory — 2026-03-18]

Facts:
- [1.00] Main branch is develop, not main  [tags: git, branch]
- [1.00] Never use default exports  [tags: typescript, exports]

Lessons:
- [0.90] Always use Zod safeParse, never parse — parse throws in route handlers  [tags: zod, api]
- [0.85] JWT: 15min expiry, refresh tokens in httpOnly cookies  [tags: auth, jwt]
- [0.78] Supabase Auth over Auth0 (cost + integration fit)  [tags: auth, architecture]

Recent Episodes:
- [0.90] Working on auth feature M3 — passport.js, 5 stories decomposed  [tags: auth, session]

[End Project Memory]
```

5. If output exceeds 500 tokens, drop lowest-confidence medium-band lessons first, then oldest episodes.
6. Update `last_accessed` and `access_count` for all injected entries.
7. Return the formatted block.

### Context Engine Hook

When composing agent prompts, the Context Engine calls `build_context()` and injects the result as a system-level block before the task description. The injection is annotated so agents know it comes from memory:

```
[CONTEXT ENGINE] Project memory injected (19 active entries, 500 token cap).
```

## Integration Points

### At Session Start

```
memory.decay_cycle()          # apply tier-based decay, archive below 0.30, promote episodes
context = memory.build_context()  # confidence-weighted context for agents
```

### At CHECKPOINT (mid-session)

```
memory.save_episode(story_summary, session_id)
```

### When User Provides Feedback

```
memory.detect_signals(user_message)
# if signals found: auto-calls remember() with inferred tier + confidence
```

### After Retrospective

```
for each approved improvement:
    memory.remember(improvement, tier="lesson", category="quality_rule", confidence=0.90)
```

### At Session End

```
memory.decay_cycle()   # not re-run at end, but maintenance_log() summarizes session delta
```

## PostCompact Hook Integration

The `PostCompact` hook (Claude Code v2.1.76+) fires after context compaction. Memory re-injection after compaction:

1. `SessionStart` hook fires with `source: "compact"`
2. `session-start-hook.sh` calls `memory.build_context()`
3. High-confidence entries (> 0.70) are always re-injected
4. Agent regains project knowledge within 1 turn after compaction

The `PostCompact` hook itself is used for audit logging only — context injection happens via `SessionStart`.

### Plugin Data (Claude Code v2.1.78+)

When `${CLAUDE_PLUGIN_DATA}` is available, use it for operational metadata:
- Decay counters (sessions since last reinforcement)
- Current session ID
- Maintenance log summaries

Full memory files (`memories.md`, `archived.md`) remain as markdown for git tracking and human readability. Plugin data supplements with fast-access operational state.

## File Management

- `memories.md` and `archived.md` are committed to git (project-specific knowledge)
- Both files live in `.maestro/memory/` which is tracked
- Memory persists across branches and collaborators
- Session-specific state (`state.local.md`) is gitignored; memory is not

## Limits

| Resource | Limit |
|----------|-------|
| Facts | No limit (permanent, manually curated) |
| Lessons | No limit (curated over time via decay) |
| Episodes | Max 20 active (oldest/lowest-confidence pruned first) |
| Context injection | Max 500 tokens |
| Confidence floor for active retrieval | 0.30 |
| Auto-promotion threshold (episode → lesson) | access_count >= 5 |
