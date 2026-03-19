---
name: security-scan
description: "Run a deep security scan on a skill or squad — static and behavioral analysis across 8 categories, producing a trust score and ACCEPTED/REVIEW/REJECTED verdict"
argument-hint: "<path> [--mode static|full] [--source imported|local|auto-generated] [--all] [--update-blocklist]"
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
  - Skill
  - AskUserQuestion
---

# Maestro Security Scan

**ALWAYS display this ASCII banner as the FIRST thing in your response, before any other output:**

```
███╗   ███╗ █████╗ ███████╗███████╗████████╗██████╗  ██████╗
████╗ ████║██╔══██╗██╔════╝██╔════╝╚══██╔══╝██╔══██╗██╔═══██╗
██╔████╔██║███████║█████╗  ███████╗   ██║   ██████╔╝██║   ██║
██║╚██╔╝██║██╔══██║██╔══╝  ╚════██║   ██║   ██╔══██╗██║   ██║
██║ ╚═╝ ██║██║  ██║███████╗███████║   ██║   ██║  ██║╚██████╔╝
╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝
```

Deep security analysis for SKILL.md files and squad definitions. Runs static and behavioral analysis across 8 categories, computes a trust score, and returns a verdict: ACCEPTED, REVIEW REQUIRED, or REJECTED.

Designed to catch hidden payloads, exfiltration hooks, and persistence mechanisms that pass surface validation — the class of attacks used in the ClawHavoc campaign.

## Step 1: Resolve Arguments

Parse `$ARGUMENTS`:

| Flag / Position | Default | Meaning |
|-----------------|---------|---------|
| `<path>` (positional) | — | Required: path to SKILL.md, squad file, or directory |
| `--mode static\|full` | `full` | `static` skips behavioral analysis (Categories 5–8) |
| `--source imported\|local\|auto-generated` | `imported` | Source context — behavioral analysis only runs for `imported` |
| `--all` | off | Scan all skills in the given directory |
| `--update-blocklist` | off | Fetch latest community blocklist and exit |
| `--blocklist <path>` | built-in | Supplement the built-in blocklist with a custom file |

### No arguments — Interactive mode

Use AskUserQuestion:
- Question: "What would you like to scan?"
- Header: "Security Scan"
- Options:
  1. label: "Scan a specific skill", description: "Provide path to a SKILL.md file"
  2. label: "Scan all installed skills", description: "Scan every skills/*/SKILL.md in this project"
  3. label: "Scan a squad", description: "Scan all skills in a squad definition"
  4. label: "Update blocklist", description: "Fetch the latest community domain blocklist"

---

## Step 2: Validate Input

### If `--update-blocklist` is set

Fetch the latest blocklist from the configured feed URL (read from `.maestro/config.yaml` under `security.blocklist_feed`). Append new entries to `.maestro/security/blocklist.txt`. Never remove existing entries automatically.

```
[maestro] Blocklist updated.
  File:     .maestro/security/blocklist.txt
  New entries added: <N>
  Total entries:     <N>
  Updated:  <today>
```

Exit after updating.

### Path validation

- If the path does not exist:
  ```
  [maestro] File not found: <path>
  ```

- If the file is binary or non-UTF-8:
  ```
  [maestro] FAIL: non-text content — <path> rejected unconditionally.
  ```

- If the file exceeds 500 KB:
  ```
  [maestro] WARNING: unusually large skill file (<N> KB). Running static analysis only.
  ```

- If `--all` is set and path is a directory, glob `<path>/**/SKILL.md` and scan each file.

---

## Step 3: Run the Scan

Invoke the security scanner logic defined in `skills/security-scanner/SKILL.md`. The full scan runs in two phases:

### Phase 1: Static Analysis (always runs)

Run all four static categories:

1. **Frontmatter Validation** — Apply all SK rules via `skill-validator`. Flag any SK Security rule failures (SK-05 through SK-10) as BLOCKING.
2. **Bash Command Analysis** — Detect dangerous patterns: remote pipe execution, broad deletion, cron creation, exfiltration, privilege escalation.
3. **URL Analysis** — Check all URLs against the blocklist, flag HTTP URLs, raw IPs, and obfuscated/shortened URLs.
4. **Content Analysis** — Scan for base64 blocks, hex strings, prompt injection markers, hidden Unicode, and homoglyph substitution.

### Phase 2: Behavioral Analysis (runs when `mode: full` and `source: imported`)

Run all four behavioral categories:

5. **File Access Scope** — Check for reads/writes outside the project root, path traversal, or access to sensitive system paths.
6. **Network Scope** — Check for outbound data transmission, raw IP connections, or persistent connections.
7. **Permission Escalation** — Check for instructions to modify hooks, settings files, CLAUDE.md, or the skills registry.
8. **Persistence** — Check for startup script writes, service/daemon installation, or self-registration as a hook.

---

## Step 4: Compute Trust Score and Verdict

```
base_score = 100
For each BLOCKING finding: base_score -= blocking_weight[category]
For each WARNING finding:  base_score -= floor(blocking_weight[category] / 2)
trust_score = max(0, base_score)
```

| Score | Band | Verdict |
|-------|------|---------|
| 90–100 | Clean | ACCEPTED |
| 75–89 | Low Risk | ACCEPTED (warnings noted) |
| 60–74 | Review Required | REVIEW — human approval needed |
| 1–59 | High Risk | REJECTED |
| 0 | Critical | REJECTED |

A skill is REJECTED if it has **any** BLOCKING finding, regardless of the numeric score.

---

## Step 5: Display Output

```
Security Scan: <skill-name>
  File: <path>
  Source: <source>
  Mode: <mode>

  Static Analysis:
    (ok) Frontmatter: 14/14 rules passed
    (ok) Bash commands: 0 dangerous patterns
    (!)  URLs: 1 HTTP URL found (line 45) — consider HTTPS
    (ok) Content: no encoded payloads or injection attempts

  Behavioral Analysis:
    (ok) File scope: reads only project files
    (ok) Network scope: no outbound data transmission
    (ok) Permission: no settings modification
    (ok) Persistence: no startup scripts or service registration

  Trust Score: <N>/100 (<BAND>)
  Blocking issues: <N>
  Warnings: <N>

  Verdict: ACCEPTED | REVIEW REQUIRED | REJECTED
  Reason: <summary — omit if ACCEPTED clean>
```

**Legend:**
- `(ok)` — category passed all checks
- `(!)` — one or more warnings (non-blocking)
- `(x)` — one or more BLOCKING issues

When `mode: static`, the Behavioral Analysis section is omitted and the header reads `Mode: static (behavioral analysis skipped)`.

---

## Step 6: Act on the Verdict

### REJECTED

```
[maestro] Skill REJECTED — cannot be accepted in current state.

  Blocking issues must be resolved before this skill can be used.
  See scan output above for exact file locations and patterns.
```

If called from an import flow (skill-pack or squad install), halt the installation and delete the downloaded file.

### REVIEW REQUIRED

```
[maestro] Skill requires human review before acceptance.
```

Use AskUserQuestion:
- Question: "This skill scored <N>/100 and has <N> warning(s). Accept anyway?"
- Header: "Security Review"
- Options:
  1. label: "Accept with warnings", description: "Install and annotate the registry with warning count"
  2. label: "Reject", description: "Do not install this skill"

### ACCEPTED (with warnings)

```
[maestro] Skill accepted. <N> warning(s) noted.

  (i) Warnings do not block acceptance but should be reviewed.
  (i) Trust score recorded in .maestro/skills-registry.md.
```

### ACCEPTED (clean)

```
[maestro] Skill accepted. Trust score: <N>/100 — no issues found.
```

---

## Scanning Multiple Files (`--all`)

When scanning a directory or squad, display a summary table followed by the full output for any non-clean result:

```
Security scan: skills/ (12 skills)

  NAME                   SCORE   VERDICT
  auth-validator         98      ACCEPTED
  data-transform         95      ACCEPTED
  external-fetcher       72      REVIEW REQUIRED  (!)
  cron-installer          0      REJECTED         (x)
  ...

  Summary: 10 accepted, 1 requires review, 1 rejected
  Run /maestro security-scan <path> for full details on any skill.
```

If scanning a squad, add:

```
  Squad verdict: REJECTED
  Reason: 1 member skill rejected (cron-installer). Fix it before installing this squad.
```

---

## Error Handling

| Error | Action |
|-------|--------|
| File not found | Print `FAIL: file not found` and exit |
| Binary/non-UTF-8 content | Print `FAIL: non-text content` and reject unconditionally |
| File > 500 KB | Warn, run static only, flag for review |
| Blocklist file missing | Warn once, continue without domain check |
| `skill-validator` unavailable | Run all categories except frontmatter; note the gap |
| Malformed YAML frontmatter | Forward parse error; Category 1 shows partial results |
