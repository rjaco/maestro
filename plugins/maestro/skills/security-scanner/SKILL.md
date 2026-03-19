---
name: security-scanner
description: "Deep security scan for skills and squads — runs static and behavioral analysis, scores threats, and blocks acceptance of malicious or high-risk content before it reaches the runtime."
---

# Security Scanner

Publish-time and import-time security gate for SKILL.md files and squad definitions. Runs two analysis phases — static (always) and behavioral (imported skills only) — across eight scan categories, then produces a threat-weighted trust score and a verdict. Designed to catch the class of attacks that enabled the ClawHavoc campaign: skills that pass surface validation but carry hidden payloads, exfiltration hooks, or persistence mechanisms.

## When to Use

- Called by `skill-pack` import flow before installing any external skill
- Called by `runtime-author` before registering any auto-generated skill
- Called by `squad` during `/maestro squad install` for community squads
- Called manually: `/maestro security-scan <path>`

## Input

- **path** — Path to the SKILL.md or squad definition file (from `$ARGUMENTS` or caller)
- **mode** — Optional: `static` | `full` (default: `full`). `static` skips behavioral analysis; `full` runs both phases.
- **source** — Optional: `imported` | `local` | `auto-generated` (default: `imported`). Behavioral analysis only runs when source is `imported`.
- **blocklist** — Optional: Path to a custom domain blocklist file. Falls back to the built-in blocklist at `.maestro/security/blocklist.txt`.

---

## Phase 1: Static Analysis

Static analysis runs on every skill regardless of source. It reads the raw file content and applies pattern matching across four categories.

---

### Category 1: Frontmatter Validation

Runs all 14 existing SK rules from `skill-validator` against the file. The security scanner does not duplicate rule logic — it calls `skill-validator` as a sub-step and incorporates its verdict table into the combined output.

**Rules applied:** SK-01 through SK-14

**Scoring:** Each failing SK rule applies the same weight defined in `skill-validator`. A skill that fails any SK Security rule (SK-05 through SK-10) is immediately flagged as a blocking issue regardless of the combined trust score.

**Output line:**
```
(ok) Frontmatter: 14/14 rules passed
(x)  Frontmatter: 2/14 rules failed — SK-06 (path traversal), SK-09 (encoded content)
```

---

### Category 2: Bash Command Analysis

Extract every bash command, shell snippet, and shell-like instruction from the skill body. Check for dangerous patterns.

**How to extract:** Scan fenced code blocks marked ` ```bash `, ` ```sh `, ` ```shell `, and ` ```zsh `. Also scan inline code spans and prose instructions that include shell metacharacters or command names.

**Blocked patterns:**

| Pattern | Example | Severity |
|---------|---------|----------|
| Remote pipe execution | `curl ... \| bash`, `wget ... \| sh`, `curl ... \| python` | BLOCKING |
| Broad deletion | `rm -rf /`, `rm -rf /*`, `rm -rf ~` | BLOCKING |
| Overly permissive chmod | `chmod 777`, `chmod a+rwx`, `chmod 0777` | BLOCKING |
| Netcat exfiltration | `\| nc `, `\| netcat `, `nc -e`, `ncat` used to send data | BLOCKING |
| Background daemonization | command ending in ` &`, `nohup <cmd>`, `disown` | WARNING |
| Cron job creation | `crontab -e`, `crontab -l`, writes to `/etc/cron*`, `*/5 * * * *` patterns | BLOCKING |
| History suppression | `unset HISTFILE`, `export HISTFILESIZE=0`, `HISTIGNORE=*` | WARNING |
| Privilege escalation | `sudo su`, `sudo -i`, `sudo bash` | WARNING |

For each finding, record the line number, the matched pattern, and the surrounding 40 characters of context.

**Output lines:**
```
(ok) Bash commands: 0 dangerous patterns
(x)  Bash commands: 2 blocking patterns — curl|bash (line 34), crontab -e (line 67)
(!)  Bash commands: 1 warning — background process via & (line 89)
```

---

### Category 3: URL Analysis

Extract all URLs from the skill body (frontmatter and Markdown). Check each URL against four criteria.

**How to extract:** Match `https?://[^\s"')]+` and bare domain patterns. Also extract URLs embedded inside backtick spans, HTML attributes, and YAML values.

**Checks:**

| Check | Condition | Severity |
|-------|-----------|----------|
| Known malicious domain | URL hostname matches the built-in or custom blocklist | BLOCKING |
| IP address as hostname | URL uses a raw IPv4 or IPv6 address instead of a domain name | WARNING |
| Non-HTTPS scheme | URL uses `http://` | WARNING |
| Obfuscated URL | URL passes through a known shortener (`bit.ly`, `tinyurl.com`, `t.co`, `ow.ly`, `is.gd`, `buff.ly`, `rebrand.ly`, `cutt.ly`) or contains base64-looking path segments longer than 32 chars | BLOCKING |

**Built-in blocklist** (stored at `.maestro/security/blocklist.txt`, one hostname per line). Seeded with domains from the ClawHavoc campaign and updated via `maestro security-scan --update-blocklist`. The blocklist file is plain text; lines starting with `#` are comments.

**Output lines:**
```
(ok) URLs: all 3 URLs pass checks
(!)  URLs: 1 HTTP URL found (line 45) — consider HTTPS
(x)  URLs: 1 blocked domain (line 12) — data-collector.malicious.io matches blocklist
```

---

### Category 4: Content Analysis

Scan the full file text for hidden payload indicators and prompt injection patterns that go beyond what SK-09 and SK-10 cover.

**Checks:**

| Check | Pattern | Severity |
|-------|---------|----------|
| Base64 blocks | Continuous base64 string longer than 32 characters anywhere in the body (outside legitimate hash display contexts) | WARNING if 32–63 chars, BLOCKING if ≥ 64 chars |
| Hex-encoded strings | Hex string longer than 20 characters outside code blocks that display commit hashes or checksums | WARNING if 20–47 chars, BLOCKING if ≥ 48 chars |
| Prompt injection — standard | Phrases covered by SK-10 (already caught by frontmatter validation, re-checked here as belt-and-suspenders) | BLOCKING |
| Prompt injection — extended | `system:`, `<system>`, `[INST]`, `[/INST]`, `<\|im_start\|>`, `HUMAN:`, `ASSISTANT:` used outside legitimate documentation context | WARNING |
| Sandbox disable instruction | The string `dangerouslyDisableSandbox` anywhere in the file (also caught by SK-05 — belt-and-suspenders) | BLOCKING |
| Hidden Unicode | Non-printable Unicode characters (categories Cf, Cc excluding tab/newline, Cs) embedded in prose | BLOCKING |
| Homoglyph substitution | Cyrillic, Greek, or other lookalike characters mixed into what appears to be ASCII identifiers or command names | WARNING |

**Context note:** Some skills legitimately document these patterns in order to warn users. A finding inside a fenced code block that is itself inside a section titled `## Security` or `## What This Does Not Do` is downgraded one severity level (BLOCKING → WARNING, WARNING → noted but not scored).

**Output lines:**
```
(ok) Content: no encoded payloads or injection attempts
(x)  Content: base64 block found (line 22, 128 chars) — potential hidden payload
(!)  Content: extended prompt injection marker "<system>" (line 56)
```

---

## Phase 2: Behavioral Analysis

Behavioral analysis only runs when `source` is `imported` (or `full` mode is active). It examines what the skill instructs agents to *do*, not just what patterns appear in the text.

---

### Category 5: File Access Scope

Read all file-access instructions: `Read`, `Write`, `Edit`, `Glob`, `Bash` commands that reference file paths, and prose instructions like "read the file at..." or "open...".

**Checks:**
- Any instruction to read or write outside the project root (paths containing `../`, absolute paths starting with `/`, home-relative paths starting with `~/` or `$HOME`)
- Any reference to sensitive locations as defined in SK-06
- Any instruction to enumerate the full file system (`find /`, `ls -R /`, `find ~`)

**Severity:** All findings are BLOCKING.

**Output lines:**
```
(ok) File scope: reads only project files
(x)  File scope: instruction to read /etc/passwd (line 33)
(x)  File scope: path traversal ../sibling-repo (line 58)
```

---

### Category 6: Network Scope

Read all network instructions: `WebFetch`, `WebSearch`, `Bash` commands with `curl`, `wget`, `nc`, `ssh`, or `scp`.

**Checks:**
- Any instruction to send data (POST body, query parameter containing `$`, file contents, project paths) to an external endpoint
- Any instruction to establish outbound connections to raw IP addresses
- Any instruction to open persistent connections (`nc -l`, `ssh -R`, `ssh -L` for tunneling)
- WebFetch calls where the URL is constructed from project-scoped variables that could contain sensitive data

**Severity:** Sending data to external endpoints: BLOCKING. Fetching from external endpoints for clearly informational purposes: WARNING.

**Output lines:**
```
(ok) Network scope: no outbound data transmission
(x)  Network scope: WebFetch to hardcoded IP 192.168.1.100 (line 78)
(!)  Network scope: WebFetch to external URL — verify intent (line 102)
```

---

### Category 7: Permission Escalation

Scan for instructions that attempt to modify Claude Code configuration, Maestro settings, or hook definitions.

**Checks:**
- Instructions to modify `.claude/settings.json` or `settings.local.json`
- Instructions to add, modify, or remove entries in `.claude/hooks/`
- Instructions to modify `CLAUDE.md` or `.claude/commands/`
- Instructions to change Maestro's own skill registry (`.maestro/skills-registry.md`) outside of a legitimate skills management context
- Instructions to grant tools or permissions the skill cannot legitimately grant (overlaps with SK-14, re-checked behaviorally here)

**Severity:** Modifying hooks or settings files: BLOCKING. Writing to CLAUDE.md or commands directory without a clear orchestrator-sanctioned purpose: WARNING.

**Output lines:**
```
(ok) Permission: no settings modification
(x)  Permission: instruction to modify .claude/hooks/pre-tool-use.sh (line 91)
(!)  Permission: instruction to write to CLAUDE.md (line 44) — verify intent
```

---

### Category 8: Persistence

Scan for instructions that could cause behavior to persist beyond the current session.

**Checks:**
- Cron job creation (also caught in Category 2 at the bash level — re-checked here at the intent level)
- Instructions to write startup scripts (`~/.bashrc`, `~/.zshrc`, `~/.profile`, `~/.bash_profile`, `/etc/rc.local`, `launchd` plist files, `systemd` unit files)
- Instructions to install system-level services or daemons
- Instructions to register the skill itself as a hook or trigger that fires on future sessions
- Instructions to modify shell history in a way that hides past activity

**Severity:** Startup script writes and service installation: BLOCKING. Self-registration as a hook with a legitimate-sounding rationale: WARNING (flag for human review).

**Output lines:**
```
(ok) Persistence: no startup scripts or service registration
(x)  Persistence: instruction to append to ~/.bashrc (line 77)
(!)  Persistence: skill registers itself as a post-session hook (line 55) — review intent
```

---

## Trust Score Computation

Compute a combined trust score after both phases complete.

```
base_score = 100

for each BLOCKING finding (any category):
  base_score -= blocking_weight[category]

for each WARNING finding (any category):
  base_score -= floor(blocking_weight[category] / 2)

trust_score = max(0, base_score)
```

**Category weights:**

| Category | Scope | Blocking Weight |
|----------|-------|----------------|
| 1 — Frontmatter (SK rules) | Static | Per SK rule weight (see skill-validator) |
| 2 — Bash commands | Static | 20 per pattern |
| 3 — URL analysis | Static | 15 per finding |
| 4 — Content analysis | Static | 20 per finding |
| 5 — File access scope | Behavioral | 25 per finding |
| 6 — Network scope | Behavioral | 25 per finding |
| 7 — Permission escalation | Behavioral | 25 per finding |
| 8 — Persistence | Behavioral | 30 per finding |

Because weights can sum beyond 100, the floor is 0. A skill with a single BLOCKING finding in Category 8 (persistence) loses 30 points; two findings in Category 5 and 7 together lose 50 points.

**Score bands:**

| Score | Band | Verdict |
|-------|------|---------|
| 90–100 | Clean | ACCEPTED — no issues |
| 75–89 | Low Risk | ACCEPTED — warnings noted |
| 60–74 | Review Required | REVIEW — human approval needed before acceptance |
| 1–59 | High Risk | REJECTED — blocking issues present |
| 0 | Critical | REJECTED — multiple blocking failures or persistence/exfiltration detected |

A skill is **REJECTED** if it has any BLOCKING finding, regardless of the numeric score. The score communicates severity; the verdict is binary at the BLOCKING threshold.

---

## Output Format

```
Security Scan: [skill-name]
  File: skills/[skill-name]/SKILL.md
  Source: imported
  Mode: full

  Static Analysis:
    (ok) Frontmatter: 14/14 rules passed
    (ok) Bash commands: 0 dangerous patterns
    (!)  URLs: 1 HTTP URL found (line 45) — consider HTTPS
    (ok) Content: no encoded payloads or injection attempts

  Behavioral Analysis:
    (ok) File scope: reads only project files
    (x)  Network scope: WebFetch to hardcoded IP 192.168.1.100 (line 78)
    (ok) Permission: no settings modification
    (ok) Persistence: no startup scripts

  Trust Score: 72/100 (REVIEW REQUIRED)
  Blocking issues: 1 (network scope — hardcoded IP 192.168.1.100, line 78)
  Warnings: 1 (non-HTTPS URL, line 45)

  Verdict: REJECTED
  Reason: 1 blocking issue — network scope violation
```

**Legend:**
- `(ok)` — category passed all checks
- `(!)` — one or more warnings (non-blocking in non-strict mode)
- `(x)` — one or more blocking issues

When `mode: static`, the Behavioral Analysis section is omitted and the header reads `Mode: static (behavioral analysis skipped)`.

---

## Integration

### skill-pack import flow

When a user runs `/skill-pack install <name>` or imports a skill from an external registry:

```
Step N (Security Gate):
  1. Run security-scanner on the downloaded SKILL.md with source: imported
  2. If verdict is REJECTED:
       a. Delete the downloaded file
       b. Print the full scan output
       c. Halt installation — do not proceed
  3. If verdict is REVIEW:
       a. Print the full scan output
       b. Prompt: "This skill requires human review. Accept anyway? [y/N]"
       c. If user declines or input is not available: halt
  4. If verdict is ACCEPTED with warnings:
       a. Print warnings summary
       b. Proceed with installation; annotate skills registry entry with warning count
  5. If verdict is ACCEPTED (clean):
       a. Proceed silently
       b. Record trust score in .maestro/skills-registry.md
```

### runtime-author

Before writing any auto-generated skill to `.claude/skills/`:

```
Step N (Security Gate):
  1. Run security-scanner on the generated content with source: auto-generated, mode: static
  2. Behavioral analysis is skipped for auto-generated skills (runtime-author is trusted)
  3. If verdict is REJECTED: discard, log to .maestro/logs/runtime-author.md, continue
  4. If verdict is ACCEPTED: proceed normally
```

### squad install

When a user runs `/maestro squad install <squad-name>`, each skill in the squad is scanned individually. A squad is rejected if any member skill is rejected.

```
  Security scan: squad "data-pipeline" (4 skills)
    (ok) ingest-csv        — trust score 98
    (ok) transform-rows    — trust score 95
    (x)  publish-results   — REJECTED (persistence: cron job, line 34)
    --   archive-logs      — skipped (preceding skill rejected)

  Squad install: REJECTED
  Fix publish-results before installing this squad.
```

### Manual invocation

```
/maestro security-scan skills/my-tool/SKILL.md
```

Static analysis only:
```
/maestro security-scan skills/my-tool/SKILL.md --mode static
```

Treat as local (skip behavioral):
```
/maestro security-scan skills/my-tool/SKILL.md --source local
```

Scan all skills in a directory:
```
/maestro security-scan skills/ --all
```

Update the domain blocklist from the community feed:
```
/maestro security-scan --update-blocklist
```

---

## Blocklist Management

The domain blocklist lives at `.maestro/security/blocklist.txt`. Format:

```
# Maestro Security Scanner — Domain Blocklist
# Updated: 2026-03-18
# Source: community feed + ClawHavoc campaign IOCs

data-collector.malicious.io
exfil-endpoint.net
claw-c2.ru
# add entries below
```

**Updating:** `--update-blocklist` fetches the latest list from the configured community feed URL (set in `.maestro/config.md` under `security.blocklist_feed`). New entries are appended; existing entries are never removed automatically. Removals require manual editing to prevent a compromised feed from whitelisting known-bad domains.

**Custom blocklist:** Pass `--blocklist path/to/custom.txt` to supplement the built-in list. Both lists are checked; a match on either triggers a BLOCKING finding.

---

## Error Handling

| Error | Action |
|-------|--------|
| File not found | Report `FAIL: file not found` and exit |
| Binary or non-UTF-8 content | Report `FAIL: non-text content` — reject unconditionally |
| File exceeds 500 KB | Report `WARNING: unusually large skill file` — run static analysis but flag for review |
| Blocklist file missing | Warn once, continue scan without domain check; do not silently skip |
| skill-validator unavailable | Run all categories except frontmatter; note the gap in output |
| Malformed YAML frontmatter | Forward the parse error from skill-validator; Category 1 shows partial results |

---

## Relationship to skill-validator

`security-scanner` is a superset of `skill-validator`, not a replacement:

| Concern | skill-validator | security-scanner |
|---------|----------------|-----------------|
| Frontmatter schema | Yes (SK-01–04) | Delegates to skill-validator |
| Security patterns in body | Yes (SK-05–10) | Delegates + extends |
| Quality and completeness | Yes (SK-11–13) | Delegates to skill-validator |
| Tool compatibility | Yes (SK-14) | Delegates to skill-validator |
| Bash command patterns | No | Yes (Category 2) |
| URL blocklist + obfuscation | No | Yes (Category 3) |
| Extended content analysis | No | Yes (Category 4) |
| Behavioral intent analysis | No | Yes (Categories 5–8) |

When both tools are in use, `security-scanner` satisfies the `skill-validator` requirement. Callers that previously invoked `skill-validator` directly do not need to call both.
