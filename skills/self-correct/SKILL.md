---
name: self-correct
description: "Personality learning system. Detects correction and confirmation signals from user messages, extracts learned traits, and persists them to SOUL.md. Promotes high-frequency corrections to Decision Principles."
---

# Self-Correct (Personality Learning)

Monitors conversation turns for signals that indicate user preferences, corrections, and confirmations. Extracts traits from those signals and persists them to `.maestro/SOUL.md` under "## Learned Traits". This makes Maestro smarter over time without requiring explicit configuration.

## Signal Detection

### Correction Signals

Patterns in user messages that indicate something Maestro did was wrong or unwanted:

| Pattern | Example |
|---------|---------|
| `don't do X` | "don't add trailing whitespace" |
| `stop doing X` | "stop summarizing what you just did" |
| `never X` | "never use default exports" |
| `no, X` | "no, use single quotes not double quotes" |
| `not X — Y` | "not camelCase — use snake_case for DB columns" |
| `I said X not Y` | implied correction of a prior action |
| `that's wrong` / `that's not right` | non-specific rejection |
| `undo that` / `revert that` | implicit correction of last action |

### Confirmation Signals

Patterns in user messages that validate something Maestro did:

| Pattern | Example |
|---------|---------|
| `perfect` | "perfect, that's exactly right" |
| `yes exactly` | "yes exactly, do it like that" |
| `keep doing that` | "keep doing that for all new components" |
| `that's right` | "that's right, always check null first" |
| `good call` | "good call on extracting that" |
| `exactly what I wanted` | |
| `that's the pattern` | "that's the pattern — remember it" |

### Signal Strength

Not all signals carry the same weight. Assign confidence when saving to semantic memory:

| Signal | Confidence |
|--------|-----------|
| Explicit "never X" / "always X" | 1.0 |
| Direct correction "don't do X" | 0.9 |
| Confirmation "yes exactly" / "keep doing that" | 0.85 |
| Implicit correction (user redoes work) | 0.7 |
| Vague rejection "that's wrong" | 0.5 |

## Learned Trait Format

Traits are appended to the `## Learned Traits` section of `.maestro/SOUL.md`.

### Correction Entry

```
- [YYYY-MM-DD] {trait_description} (source: "{correction_signal}")
```

Examples:
```
- [2026-03-10] Never add trailing whitespace to markdown files (source: "stop adding trailing spaces")
- [2026-03-14] Use snake_case for database column names, not camelCase (source: "not camelCase — use snake_case for DB columns")
- [2026-03-15] Do not summarize completed actions at end of response (source: "stop summarizing what you just did")
```

### Confirmation Entry

```
- [YYYY-MM-DD] CONFIRMED: {what_was_confirmed}
```

Examples:
```
- [2026-03-12] CONFIRMED: Terse commit messages preferred — inferred from prior corrections
- [2026-03-16] CONFIRMED: Extract shared logic into utils before implementing feature stories
- [2026-03-17] CONFIRMED: Always run tests before committing, even for trivial changes
```

## Operations

### detect_signals(user_message, assistant_response)

Scan a conversation turn for personality signals.

1. Check `user_message` against correction signal patterns
2. Check `user_message` against confirmation signal patterns
3. For each match:
   - Extract the trait description (what behavior is being corrected or confirmed)
   - Determine signal type: `correction` | `confirmation`
   - Assign confidence based on signal strength
4. Return list of detected signals: `[{type, trait, confidence, raw_signal}]`

### extract_trait(signal)

Convert a raw signal into a clean, actionable trait description.

1. Remove filler words ("like", "um", "you know")
2. Normalize to imperative form for corrections: "don't add X" → "Never add X"
3. Normalize to present-tense statement for confirmations: "that's the right way" → "Use [pattern] — confirmed by user"
4. Trim to one sentence maximum
5. Return the normalized trait string

### append_to_soul(trait_entry, signal_type)

Write a learned trait to SOUL.md.

1. Read `.maestro/SOUL.md`
2. Find the `## Learned Traits` section
3. Check for a duplicate or near-duplicate trait (same subject):
   - If exact match: skip (already recorded)
   - If near-match (same subject, different wording): replace with newer entry
4. Append the new entry in the correct format:
   - Correction: `- [date] {trait} (source: "{raw_signal}")`
   - Confirmation: `- [date] CONFIRMED: {trait}`
5. Write updated file

### check_promotion_threshold()

Check if any correction has appeared enough times to be promoted to Decision Principles.

1. Read all correction entries from `## Learned Traits`
2. Group by subject (semantic similarity, not exact match)
3. For any subject with 3 or more correction entries:
   - Extract the core principle (the most recent, clearest statement)
   - Format as a Decision Principle: `{N+1}. {principle}`
   - Prompt user: `This correction has appeared 3 times. Promote to Decision Principle?`
   - If confirmed:
     - Add to `## Decision Principles` in SOUL.md
     - Remove the individual correction entries from Learned Traits (consolidated)
     - Log: `Promoted to principle: "{principle}"`

### process_turn(user_message, assistant_response)

Main entry point. Called after every conversation turn.

1. Call `detect_signals(user_message, assistant_response)`
2. If no signals detected, return (no-op — most turns have no signals)
3. For each detected signal:
   - Call `extract_trait(signal)`
   - Call `append_to_soul(trait_entry, signal.type)`
   - Also call `memory.save_semantic(trait, "user_preference", signal.confidence)` to sync with memory system
4. After appending all new traits, call `check_promotion_threshold()`
5. Return summary of changes (for logging, not for display):
   ```
   Learned: 1 correction, 0 confirmations
   Traits total: 7
   Promotions pending: 0
   ```

## SOUL.md Update Flow

```
User: "stop summarizing what you just did at the end of every response"

detect_signals() → correction signal detected
extract_trait()  → "Do not summarize completed actions at end of response"
append_to_soul() → appends to ## Learned Traits

SOUL.md after update:
  ## Learned Traits
  - [2026-03-15] Do not summarize completed actions at end of response (source: "stop summarizing what you just did at the end of every response")
```

```
User: "yes exactly, always check null before accessing nested properties"

detect_signals() → confirmation signal detected
extract_trait()  → "Always check for null before accessing nested properties"
append_to_soul() → appends confirmed trait

SOUL.md after update:
  ## Learned Traits
  - [2026-03-15] CONFIRMED: Always check for null before accessing nested properties
```

## Promotion Flow

```
Session 1: "don't use default exports"
Session 3: "stop using default exports, I've said this before"
Session 5: "no default exports, ever"

check_promotion_threshold() detects 3 corrections on same subject

→ Prompt: This correction appeared 3 times: "no default exports". Promote to Decision Principle?
→ User confirms

SOUL.md Decision Principles after promotion:
  6. No default exports — always use named exports
```

## Integration Points

### In Dev-Loop (after every user message)

```
self_correct.process_turn(user_message, assistant_response)
```

### In SOUL Skill

When `soul.inject()` is called, the Learned Traits section (populated by self-correct) is included in the SOUL context block automatically. No explicit coupling needed.

### In Memory Skill

After appending a trait, self-correct also calls `memory.save_semantic()` to keep the memory system in sync. The trait is saved under the `user_preference` category with the assigned confidence score.

### In Learning Loop

self-correct does not call learning-loop directly. Instead, it writes correction and confirmation entries to `.maestro/SOUL.md` `## Learned Traits`. The `learning-loop` skill reads those entries during its RETRIEVE phase at the start of each milestone run and ingests any entries dated within the current milestone as `user_correction` signals.

### Data Contract with learning-loop

- **Output location**: `.maestro/SOUL.md` — `## Learned Traits` section
- **Format**: Markdown list entries (appended by `append_to_soul`)
- **Written by**: `self-correct`
- **Read by**: `learning-loop` RETRIEVE phase
- **Correction entry format**: `- [YYYY-MM-DD] {trait_description} (source: "{raw_signal}")`
- **Confirmation entry format**: `- [YYYY-MM-DD] CONFIRMED: {trait_description}`
- **Confidence mapping** (used by learning-loop when ingesting):
  - Entries starting with `CONFIRMED:` → confidence 0.85
  - Entries containing `(source: "never …"` or `"always …"` → confidence 1.0
  - All other correction entries → confidence 0.9

## What Self-Correct Does NOT Do

- Does not modify Decision Principles without user confirmation (see promotion flow)
- Does not delete traits (only replaces near-duplicates on the same subject)
- Does not process signals from agent-to-agent messages — only from the user
- Does not run on every token — only processes complete conversation turns
- Does not retroactively scan conversation history — only processes turns as they happen

## Error Handling

| Error | Action |
|-------|--------|
| SOUL.md not found | Call `soul.initialize()` first, then retry |
| Trait extraction returns empty string | Skip — do not append empty traits |
| SOUL.md write fails | Log warning, continue (non-blocking) |
| Promotion prompt times out | Skip promotion, re-check next session |
