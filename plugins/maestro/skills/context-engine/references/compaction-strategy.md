# Adaptive Context Compaction Strategy

Progressive compaction triggered as token usage approaches the model's context limit. Stages advance in sequence — never backwards — within a session. Each stage sacrifices the least valuable context first, preserving execution continuity.

## Trigger Mechanism

Token usage is estimated from message count and average token density (~800 tokens/message). Compaction checks run at each story boundary in the dev-loop, after each agent dispatch returns, and between milestones in the opus-loop. Only advance stages — never go backward. Log each stage transition to `.maestro/context-log.md`.

---

## Stage 1: Selective Truncation (60% capacity)

**Keep:** All code being edited, all decisions and rationale, current story spec, unresolved errors, user messages and notes.

**Compress:** Verbose tool output → 3-line summary with key finding. Redundant status messages → single aggregate line.

**Remove:** Exploration results already incorporated into decisions. Duplicate context blocks from multiple dispatches. Intermediate scratch work that produced a final artifact.

---

## Stage 2: Summarization (70% capacity)

**Keep at full fidelity:** Current story spec, acceptance criteria, QA feedback, most recent unresolved error, North Star / vision.

**Compress:** Each completed story → 3-line summary (outcome, key decisions, patterns learned). Past QA feedback from stories 2+ back → single aggregated lessons line.

**Remove:** Full conversation transcripts for completed stories. Tool call details from already-merged worktrees.

**Completed story summary format:**
```
[Story 03-api-routes: DONE] Added rate-limited search endpoint.
Decisions: Upstash Redis with in-memory fallback; Zod v4 safeParse.
Lesson: QA flagged missing error handler — fixed in final pass.
```

---

## Stage 3: Memory Offloading (80% capacity)

**Write to `.maestro/memory/episodic.md`:** Architecture decisions, file locations, user preferences, QA lessons, any "always / never / use X instead of Y" facts.

**Write to `.maestro/state.local.md`:** Current progress snapshot (story index, tokens spent, phase).

**Drop from active context:** All offloaded facts, completed-milestone research, reference docs already acted upon.

**Do NOT offload:** Current story spec, unresolved errors, user messages from this session, security-relevant context.

---

## Stage 4: Episodic Pruning (90% capacity)

**Keep:** Vision / North Star (re-injected from `.maestro/vision.md`), current story full context, state file (milestone, story index, mode), last 2 completed story summaries.

**Prune:** All story history beyond the last 2, all completed-milestone execution details, episodic memory entries in the active window (they are on disk), all research context.

**Do NOT prune:** Code actively being edited, unresolved errors, user messages and notes from this session, security-relevant context.

---

## Stage 5: Full Reset with Handoff (95% capacity)

**Save to disk before reset:**
- `.maestro/state.local.md` — full progress: milestone, story index, stories status, tokens spent, active mode
- `.maestro/memory/episodic.md` — all session learnings: decisions, preferences, QA lessons, file locations
- `.maestro/registry.json` — requirements status: criteria verified, stories complete vs pending
- `.maestro/memory/compaction-handoff.md` — last action taken, current story summary, immediate next step

**Trigger:** Invoke Stop hook to end the current context window and start fresh.

**New context starts with:** `.maestro/vision.md` (full), `.maestro/state.local.md` (full), current story spec only, handoff note.

---

## What to Preserve at Every Stage

| Always Keep | Rationale |
|-------------|-----------|
| North Star / vision | Prevents drift during long autonomous runs |
| Current story spec and acceptance criteria | Cannot implement without it |
| Most recent unresolved QA feedback or error | Self-heal depends on exact text |
| State file path and format | Session resumability |
| User messages and notes | User intent is never expendable |

## What to Never Compress

| Never Compress | Rationale |
|----------------|-----------|
| Code actively being edited | Corrupts the diff |
| Unresolved error messages | Fix agent needs exact error text |
| User messages and notes | Instructions, not context noise |
| Security-relevant context | Auth flows, key references — compress at risk |

---

## Integration Points

| Skill | Compaction Role |
|-------|-----------------|
| `context-engine/SKILL.md` | Owns this strategy; applies before each package composition |
| `dev-loop/SKILL.md` | Checks compaction stage between stories (before Phase 2: DELEGATE) |
| `opus-loop/SKILL.md` | Checks compaction stage between milestones (before MILESTONE START) |
| `memory/SKILL.md` | Receives offloaded context in Stage 3 via `save_episodic()` and `save_semantic()` |
