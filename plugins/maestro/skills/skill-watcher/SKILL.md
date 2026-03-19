---
name: skill-watcher
description: "Session-scoped SKILL.md change detector. Snapshots modification times at session start and tracks edits during the session. Reports loaded, modified, skipped, and shadowed skill counts via /maestro skills --check."
---

# Skill Watcher

Monitors SKILL.md files for changes during a Maestro session. Takes a modification-time snapshot at session start and detects edits without polling — changes are noted and logged so the user knows which skills will behave differently next session.

## Session-Scoped Snapshot

### At Session Start

When the Maestro session initializes, snapshot the mtime (last modification time) of every discovered SKILL.md file.

**Step-by-step:**

1. Collect the full list of active SKILL.md paths from the skill-loader (all three tiers, after precedence resolution, including skipped skills).
2. For each path, record the mtime using `stat -c %Y <path>` (Linux) or `stat -f %m <path>` (macOS).
3. Store the snapshot in memory for the duration of the session. The snapshot does not persist to disk — it is session-scoped only.
4. Log a single line to `.maestro/logs/skill-watcher.log`:

```
[2026-03-18T14:00:01Z] SNAPSHOT 47 skill files captured at session start
```

### During the Session

After the snapshot is taken, the watcher checks for changes on each invocation of the skill-watcher (not on a polling schedule — triggered by `/maestro skills --check` or at session end).

**Change detection algorithm:**

1. Re-stat every path in the snapshot.
2. Compare the current mtime to the snapshotted mtime.
3. If any file's mtime has advanced, it has been modified during the session.
4. For each modified file, log an entry to `.maestro/logs/skill-watcher.log`:

```
[2026-03-18T14:05:00Z] MODIFIED skills/dev-loop/SKILL.md — changes will take effect next session
```

Format: `[<ISO8601 timestamp>] MODIFIED <relative-path> — changes will take effect next session`

5. Also detect new SKILL.md files that were not in the snapshot (added during the session):

```
[2026-03-18T14:06:00Z] ADDED skills/example-new/SKILL.md (example) — will be loaded next session
```

6. Detect SKILL.md files that were in the snapshot but no longer exist:

```
[2026-03-18T14:07:00Z] REMOVED skills/example-old/SKILL.md (example) — will be unloaded next session
```

All log entries use append-only writes to `.maestro/logs/skill-watcher.log`.

## Command: `/maestro skills --check`

When the user runs `/maestro skills --check`, display a formatted status report.

### Report Format

```
+---------------------------------------------+
| Maestro Skills                              |
+---------------------------------------------+

  Loaded:    42 skills active this session
  Skipped:    3 skills (dependency gates unmet)
  Shadowed:   2 skills (overridden by higher-tier versions)

  Modified since session start:
    (!) skills/dev-loop/SKILL.md
        Changes will take effect next session.
    (!) skills/context-engine/SKILL.md
        Changes will take effect next session.

  Skipped skills:
    (x) audio-encode      requires_bins 'ffmpeg' not found
    (x) cloud-deploy      requires_env 'AWS_ACCESS_KEY_ID' not set
    (x) video-encoder     requires_os 'darwin' (current: linux)

  Shadowed skills:
    (~) dev-loop          workspace ./skills/dev-loop shadows bundled
    (~) context-engine    global ~/.maestro/skills/context-engine shadows bundled

  ---- 42 loaded, 3 skipped, 2 shadowed, 2 modified ----
```

### Section Rules

- **Loaded** — Count of skills that passed gate evaluation and are active.
- **Skipped** — Count of skills whose dependency gates were unmet. List each with the failing gate.
- **Shadowed** — Count of skills suppressed by a higher-tier skill with the same name. List each with the winning path.
- **Modified since session start** — Only shown if one or more SKILL.md files have changed since the snapshot. If no changes, omit this section.
- If no skills were skipped, omit the Skipped section (or show `(ok) No skills skipped`).
- If no skills were shadowed, omit the Shadowed section.

## Log File

All watcher events are appended to `.maestro/logs/skill-watcher.log`. Create `.maestro/logs/` if it does not exist.

### Log Entry Types

| Event | Format |
|-------|--------|
| Session snapshot | `[timestamp] SNAPSHOT <n> skill files captured at session start` |
| Modified file | `[timestamp] MODIFIED <path> — changes will take effect next session` |
| Added file | `[timestamp] ADDED <path> — will be loaded next session` |
| Removed file | `[timestamp] REMOVED <path> — will be unloaded next session` |

### Log Rotation

Do not rotate the log file automatically. The log is human-readable and grows slowly. Users can truncate it manually. Entries older than 30 days may be pruned by `memory_maintenance()` if it is configured to manage log files.

## Integration Points

- **Invoked by:** session start (to take the snapshot), `/maestro skills --check`
- **Reads from:** skill-loader's active skill list + mtime data from the filesystem
- **Writes to:** `.maestro/logs/skill-watcher.log` (append-only)
- **Depends on:** `skill-loader` (must run first to provide the discovered skill list)
- **Referenced by:** `/maestro doctor` (uses skipped/shadowed counts in its Skills section)
