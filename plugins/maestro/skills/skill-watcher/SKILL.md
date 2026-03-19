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

## Integration Points

| Skill / Component | Integration |
|-------------------|-------------|
| `skill-loader` (internal) | Calls mtime check before each skill load; emits change notice on drift |
| `delegation/SKILL.md` | Session-start hook triggers `skill_snapshot` write before first dispatch |
| `audit-log/SKILL.md` | Change notices are logged as `skill_drift` events with skill name and timestamp |
| `rules-doctor/SKILL.md` | Reads `skill_snapshot.taken_at` to determine whether its own rules reflect the latest skill versions |
