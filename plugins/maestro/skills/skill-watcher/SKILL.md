---
name: skill-watcher
description: "Development-time watcher for skill file changes. Snapshots mtime at session start and detects edits to SKILL.md files. New sessions pick up changes automatically; active sessions log the change and continue safely."
---

# Skill Watcher

Detects edits to `skills/*/SKILL.md` files during development. Takes a modification-time snapshot when a session starts, compares against it to surface stale-load warnings, and ensures new sessions always read the latest version of every skill.

## Core Principle

Skills are loaded once per session. Mid-session hot-swap is intentionally disabled — a half-loaded skill could produce inconsistent behavior if it changes while an agent is mid-execution. Instead, the watcher surfaces a clear message and defers the reload to the next session start.

```
Session start                Session running              New session
     │                             │                           │
     ▼                             ▼                           ▼
Snapshot all skill          Check mtime on each         Load all skills fresh
mtime values into           skill access; emit          from disk — snapshot
state.local.md              change notice if drift      taken at this point
```

## Snapshot Format

At session start, write the `skill_snapshot` field to `.maestro/state.local.md`:

```yaml
skill_snapshot:
  taken_at: "2026-03-18T14:00:00Z"
  skills:
    delegation:    1742301600   # Unix mtime of skills/delegation/SKILL.md
    model-router:  1742298000
    dev-loop:      1742285400
    # ... one entry per skill with a SKILL.md
```

Only skills with a `SKILL.md` at the top level of their directory are included. Reference documents (e.g., `skills/kanban/provider-github.md`) are not tracked.

## Detection: Checking for Drift

The skill-loader checks mtime before loading any skill. Compare the current mtime of `skills/<name>/SKILL.md` against the value in `skill_snapshot.skills.<name>`.

| Comparison | Result |
|------------|--------|
| mtime == snapshot value | No change — load normally |
| mtime > snapshot value | Changed since session start — emit notice |
| snapshot entry missing | New skill added — emit notice |
| file deleted | Skill removed — skip load, emit notice |

### Emitting a Change Notice

When drift is detected for a skill named `<name>`, emit this message before the skill's output:

```
[skill-watcher] skills/<name>/SKILL.md changed since session start.
                Reload takes effect next session. Current session uses the version loaded at start.
```

Do not block execution. Do not reload the skill. Continue with the snapshot version.

## Loader Integration

When skill-loader fetches a skill for dispatch:

1. Look up `<name>` in `skill_snapshot.skills`.
2. Read current `stat().mtime` for `skills/<name>/SKILL.md`.
3. If mtime differs, emit the change notice (see above).
4. Proceed with the originally loaded skill content.

This check is intentionally lightweight — it reads only `stat()` metadata, not the file contents.

## Session Start Procedure

On every session start (before any dispatch):

1. Enumerate all directories under `skills/` that contain a `SKILL.md`.
2. For each, record `stat().mtime` as a Unix timestamp.
3. Write the snapshot block to `.maestro/state.local.md` under `skill_snapshot`.
4. If a previous snapshot exists, compare the two and log any skills that changed between sessions:

```
[skill-watcher] Skills updated since last session:
  model-router — modified 2 minutes ago
  dev-loop     — modified 1 hour ago
```

This gives the developer immediate confirmation that their edits were picked up.

## Developer Workflow

```
1. Edit  skills/my-skill/SKILL.md   ← save the file
2. End current session               ← changes are NOT applied mid-session
3. Start a new session               ← skill-watcher snapshots the new mtime
4. Dispatch uses the updated skill   ← new version is active
```

No command needed — the watcher is automatic at every session start.

## Commands

| Command | Action |
|---------|--------|
| `skill-watcher status` | Show snapshot timestamp and list any skills that changed since it was taken |
| `skill-watcher diff` | For each changed skill, show which fields differ (name, description, section headers) |
| `skill-watcher snapshot refresh` | Force a new snapshot without restarting the session (for development use only — does NOT reload skill content) |

## State Schema

Fields written to `.maestro/state.local.md`:

| Field | Type | Description |
|-------|------|-------------|
| `skill_snapshot.taken_at` | ISO 8601 string | When the snapshot was recorded |
| `skill_snapshot.skills.<name>` | integer | Unix mtime of `skills/<name>/SKILL.md` at snapshot time |

## mtime Comparison Algorithm

The following pseudocode describes the full comparison logic executed at session start and on each skill access.

```
# --- Session Start ---
function take_snapshot():
  snapshot = {}
  snapshot.taken_at = now_utc_iso()
  for each directory D in skills/*/:
    path = D + "/SKILL.md"
    if file_exists(path):
      snapshot.skills[basename(D)] = stat(path).mtime  # Unix timestamp

  previous = read_skill_snapshot_from_state()
  write_skill_snapshot_to_state(snapshot)

  if previous exists:
    for each name in union(previous.skills.keys, snapshot.skills.keys):
      if name not in previous.skills:
        log_event(NEW, name, snapshot.skills[name])
      elif name not in snapshot.skills:
        log_event(DELETED, name, previous.skills[name])
      elif snapshot.skills[name] > previous.skills[name]:
        log_event(CHANGED, name, snapshot.skills[name])
  return snapshot

# --- Per-Access Check (called by skill-loader) ---
function check_drift(name, snapshot):
  path = "skills/" + name + "/SKILL.md"

  if not file_exists(path):
    if name in snapshot.skills:
      emit_change_notice(DELETED, name)
    return DELETED

  current_mtime = stat(path).mtime

  if name not in snapshot.skills:
    emit_change_notice(NEW, name)
    return NEW

  if current_mtime > snapshot.skills[name]:
    emit_change_notice(CHANGED, name)
    return CHANGED

  return UNCHANGED
```

## Deletion Handling

When a `SKILL.md` file is removed from disk:

1. `check_drift()` detects `file_exists(path) == false` and the name is still in the snapshot.
2. A `DELETED` notice is emitted (see log format below).
3. The skill-loader skips loading the skill — it is treated as unavailable for the remainder of the session.
4. At the **next session start**, `take_snapshot()` does not find the directory, so the skill is absent from the new snapshot. The deletion is implicitly reconciled.
5. A `skill_drift` event with type `DELETED` is written to the audit log (via `audit-log/SKILL.md`), including the skill name and the timestamp from the old snapshot entry.

The snapshot itself is **not mutated mid-session** when a deletion is detected. The stale entry remains until the next session start rebuilds the snapshot from disk.

## New Skill Detection Algorithm

New skills are detected at session start by comparing the directory scan against the previous snapshot.

```
# During take_snapshot(), after writing the new snapshot:
for each name in snapshot.skills:
  if name not in previous.skills:
    log "[skill-watcher] NEW skill detected: <name> (mtime: <ts>)"
    write to skill-loader.md: "New skill <name> available as of session <session_id>"
```

At **mid-session access** time, if skill-loader tries to load a skill whose name is absent from the snapshot (i.e., a directory appeared after session start), `check_drift()` returns `NEW` and emits a notice. The skill is still loaded — new skills do not have a stale-content risk because there is no previously loaded version to conflict with.

## Snapshot Persistence Across Sessions

The snapshot is stored in `.maestro/state.local.md` under the `skill_snapshot` key (see Snapshot Format above).

**Write:** At the end of `take_snapshot()` (called during session start), the new snapshot is serialized as YAML and written to `state.local.md`. This file is not committed to git — it is local developer state only.

**Read:** At the start of `take_snapshot()`, the previous snapshot is read from `state.local.md` before the new one is written. This enables inter-session diff reporting.

**If `state.local.md` does not exist** (first-ever session or file was deleted): treat `previous` as empty — all skills on disk are logged as `NEW` for informational purposes only, with no error raised.

**If the YAML is malformed:** Log a warning and proceed as if no previous snapshot exists. Do not crash.

## Log Format

All watcher events use a consistent line format. Examples for each event type:

**CHANGED** — skill file was modified since the snapshot was taken:
```
[skill-watcher] CHANGED  delegation       mtime=1742305200  (was 1742301600, delta=+3600s)
[skill-watcher] CHANGED  model-router     mtime=1742306000  (was 1742298000, delta=+8000s)
```

**DELETED** — skill directory or SKILL.md no longer exists on disk:
```
[skill-watcher] DELETED  old-feature-flag  last_seen=1742285400
```

**NEW** — skill directory appeared that was not in the previous snapshot:
```
[skill-watcher] NEW      payments          mtime=1742310000
[skill-watcher] NEW      notifications     mtime=1742310045
```

**Session-start summary** (printed after all inter-session diffs are computed):
```
[skill-watcher] Snapshot taken at 2026-03-18T15:30:00Z (27 skills indexed)
[skill-watcher] Skills updated since last session:
  CHANGED  model-router     — 2 minutes ago
  CHANGED  dev-loop         — 1 hour ago
  NEW      payments         — just now
```

**Mid-session drift notice** (printed before the skill's output when drift is detected at access time):
```
[skill-watcher] skills/model-router/SKILL.md changed since session start.
                Reload takes effect next session. Current session uses the version loaded at start.
```

## skill-loader Integration Trace

The following trace shows the exact call sequence when skill-loader dispatches a skill.

```
User invokes: /maestro dev-loop

skill-loader.dispatch("dev-loop"):
  1. watcher.check_drift("dev-loop", session_snapshot)
       → stat("skills/dev-loop/SKILL.md").mtime = 1742306000
       → snapshot["dev-loop"] = 1742285400
       → 1742306000 > 1742285400  →  CHANGED
       → emit "[skill-watcher] skills/dev-loop/SKILL.md changed since session start..."
  2. load cached skill content (version from session start, not current disk state)
  3. dispatch skill with cached content
  4. audit-log writes: {event: "skill_drift", skill: "dev-loop", type: "CHANGED", ts: ...}
```

For an unchanged skill, step 1 returns `UNCHANGED` with no output emitted and no audit entry written.

## Integration Points

| Skill / Component | Integration |
|-------------------|-------------|
| `skill-loader` (internal) | Calls `watcher.check_drift(name, snapshot)` before each skill load; emits change notice on drift; loads cached content regardless of result |
| `delegation/SKILL.md` | Session-start hook triggers `watcher.take_snapshot()` before first dispatch; summary is printed to the session log |
| `audit-log/SKILL.md` | CHANGED and DELETED events are logged as `skill_drift` audit entries with skill name, event type, and timestamp |
| `rules-doctor/SKILL.md` | Reads `skill_snapshot.taken_at` to determine whether its own rules reflect the latest skill versions |
