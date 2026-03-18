---
name: security-drift
description: "Detect unauthorized modifications to critical Maestro files. Generates SHA-256 baselines on init/doctor, compares on session start, alerts on unexpected changes without blocking execution."
---

# Security Drift Detection

Detects prompt injection and tampering by tracking SHA-256 hashes of critical configuration and skill files. Inspired by ClawSec and OWASP Top 10 for Agentic Applications.

## Critical Files

Monitor these files for unauthorized modification:

```
CLAUDE.md                          # project instructions (root)
.claude/CLAUDE.md                  # project instructions (nested)
skills/*/SKILL.md                  # all skill definitions
agents/*.md                        # agent definitions
hooks/*.sh                         # hook scripts
.claude-plugin/plugin.json         # plugin manifest
.maestro/dna.md                    # project DNA
```

## Baseline Format

Store hashes in `.maestro/security/baseline.json`:

```json
{
  "generated_at": "2026-03-18T12:00:00Z",
  "files": {
    "CLAUDE.md": "sha256:abc123...",
    "skills/dev-loop/SKILL.md": "sha256:def456...",
    "hooks/stop-hook.sh": "sha256:789abc..."
  }
}
```

## Generating a Baseline

Run on `maestro init` or `maestro doctor`:

```bash
# Find all critical files and hash them
for pattern in "CLAUDE.md" ".claude/CLAUDE.md" "skills/*/SKILL.md" \
               "agents/*.md" "hooks/*.sh" \
               ".claude-plugin/plugin.json" ".maestro/dna.md"; do
  for file in $(ls $pattern 2>/dev/null); do
    sha256sum "$file"
  done
done
```

Write output to `.maestro/security/baseline.json`. Skip files that do not exist yet — they will be added when first created.

## Drift Detection Algorithm

On session start, for each file in `baseline.json`:

1. Compute current SHA-256 hash
2. Compare against stored hash
3. Check git status of the file (`git status --short <file>`)

Classify the result:

| Current Hash | Git Status | Classification |
|---|---|---|
| Matches baseline | Any | Unchanged |
| Differs | Tracked (modified/staged) | Expected change |
| Differs | Untracked or clean | Unexpected change |
| File missing | — | Deleted (unexpected) |

## Drift Report

Print to stdout and append to `.maestro/logs/security.md`:

```
Security Drift Check — 2026-03-18T12:00:00Z

  CLAUDE.md                    unchanged
  skills/dev-loop/SKILL.md     MODIFIED (hash mismatch — not in git)
  hooks/stop-hook.sh           unchanged
  .maestro/dna.md              changed (expected — git tracked)
```

Use plain markers: `unchanged`, `changed (expected)`, `MODIFIED`, `DELETED`.

## Alert Actions

When unexpected drift is detected:

1. **Log** the finding to `.maestro/logs/security.md` with timestamp, file path, and previous vs. current hash
2. **Notify** via the `notify` skill at severity `warning` if configured
3. **Do not block** — alert and let the user decide. Execution continues
4. **Add a note** to `.maestro/notes.md` so dev-loop picks it up at the next story boundary

Alert format for notify/notes:

```
[security-drift] Unexpected modification: skills/dev-loop/SKILL.md
  Was: sha256:def456...
  Now: sha256:999aaa...
  Action: review the change before continuing
```

## Baseline Update Rules

Update `.maestro/security/baseline.json` after legitimate changes:

- **Auto-update**: after a successful `git commit`, re-hash only the files that were part of that commit
- **Force regenerate**: `maestro doctor --refresh-baseline` re-hashes all critical files unconditionally
- **Never update** for files not currently in the git staging area or a completed commit — this prevents a tampered file from laundering itself into the baseline

Update procedure:

```bash
# After git commit, get changed files from last commit
git diff-tree --no-commit-id -r --name-only HEAD
# Re-hash those files and update their entries in baseline.json
```

## Integration Points

| Trigger | Action |
|---|---|
| `maestro init` | Generate initial baseline |
| `maestro doctor` | Run drift check, report results |
| `maestro doctor --refresh-baseline` | Force regenerate all hashes |
| Session start (awareness heartbeat) | Run drift check, alert on unexpected changes |
| Before first story in dev-loop | Run drift check; if unexpected drift, warn before dispatching implementer |
| Before PR in ship | Run drift check; if unexpected drift, surface warning in pre-ship report |
| After `git commit` (git-craft) | Auto-update baseline for committed files |

## Log Format

Entries appended to `.maestro/logs/security.md`:

```markdown
## 2026-03-18T12:00:00Z — Drift Check

| File | Status | Detail |
|---|---|---|
| CLAUDE.md | unchanged | — |
| skills/dev-loop/SKILL.md | MODIFIED | hash mismatch, not in git |
| hooks/stop-hook.sh | unchanged | — |
```
