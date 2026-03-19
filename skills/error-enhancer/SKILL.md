---
name: error-enhancer
description: "Transform raw error output (exit codes, stderr, exception text) into actionable messages with cause and fix suggestion. Classifies against a pattern database; falls back to category-level guidance."
---

# Error Enhancer

Converts raw error output into structured, actionable messages. Every enhanced
error includes what went wrong, why it likely happened, and specific steps to
fix it.

## Input

Accept any combination of:
- `exit_code` — numeric exit code from a failed command
- `stderr` — raw stderr text
- `message` — exception message or error string
- `service` — optional service name that produced the error (e.g. `vercel`, `aws`)
- `command` — optional command that was run

## Pattern Database

Match the error text against these patterns in order. Use the first match.

### CLI Not Installed

| Pattern | Fix |
|---------|-----|
| `command not found: aws` | Install: `brew install awscli` (macOS) or `apt install awscli` (Linux) |
| `command not found: vercel` | Install: `npm i -g vercel` |
| `command not found: gh` | Install: `brew install gh` (macOS) or see cli.github.com/manual/installation |
| `command not found: terraform` | Install: see developer.hashicorp.com/terraform/install |
| `command not found: docker` | Install: see docs.docker.com/engine/install |
| `command not found: <any>` | Install the missing CLI or add it to your PATH |

### Authentication

| Pattern | Fix |
|---------|-----|
| `401 Unauthorized` | Re-run: `/maestro connect <service>` to update credentials |
| `403 Forbidden` | Check your API key permissions at the service's dashboard |
| `Authentication failed` | Re-run: `/maestro connect <service>` to update credentials |
| `Invalid token` | Generate a new token and update the relevant environment variable |
| `Unauthorized` | Re-run: `/maestro connect <service>` to update credentials |

### Rate Limiting

| Pattern | Fix |
|---------|-----|
| `429 Too Many Requests` | Wait 60 seconds and retry, or check your plan limits |
| `rate limit exceeded` | Wait 60 seconds and retry, or check your plan limits |
| `quota exceeded` | Check usage limits at the service's billing dashboard |

### Network

| Pattern | Fix |
|---------|-----|
| `ECONNREFUSED` | Check your internet connection or the service's status page |
| `ENOTFOUND` | Check your internet connection or the URL |
| `ETIMEDOUT` | Check your internet connection or the service's status page |
| `timeout` | Retry or check service status. Consider increasing timeout. |
| `Network Error` | Check your internet connection or the service's status page |
| `connect EACCES` | Check firewall rules or network proxy settings |

### File System

| Pattern | Fix |
|---------|-----|
| `no such file or directory: .maestro/services.yaml` | Run: `/maestro setup` to configure services |
| `no such file or directory: .maestro/config.yaml` | Run: `/maestro init` to initialize the project |
| `no such file or directory: .maestro/dna.md` | Run: `/maestro init` to set up Maestro |
| `no such file or directory` | Check the path exists: `ls -la <path>` |
| `Permission denied` | Check file permissions: `ls -la <path>`, then `chmod u+rw <path>` |
| `EACCES` | Check file permissions: `ls -la <path>`, then `chmod u+rw <path>` |
| `ENOSPC` | Disk full. Free space: `df -h .`, then delete unused files or artifacts |
| `Read-only file system` | Check mount options or run as the correct user |

### Environment / Config

| Pattern | Fix |
|---------|-----|
| `STRIPE_API_KEY not set` | Set it: `export STRIPE_API_KEY='sk_...'` |
| `not set` (any env var `_KEY`, `_TOKEN`, `_SECRET`) | Set the variable: `export <VAR>='value'`, or add to `.env` |
| `missing required environment variable` | Check `.env.example` for required variables |

### Git

| Pattern | Fix |
|---------|-----|
| `merge conflict` | Resolve conflicts manually, then: `git add . && git commit` |
| `CONFLICT` | Resolve conflicts manually, then: `git add . && git commit` |
| `branch already exists` | Delete: `git branch -D <branch>` or use a different name |
| `nothing to commit` | All changes are already committed |
| `detached HEAD` | Run: `git checkout <branch-name>` to return to a branch |
| `non-fast-forward` | Pull first: `git pull --rebase origin <branch>` |

## Enhanced Error Format

```
[maestro] (x) <service or command> failed

  Error:   <raw error, trimmed to 1 line>
  Service: <service if known>
  Cause:   <human-readable cause>

  Fix:
    1. <step 1>
    2. <step 2>
    3. <step 3 if applicable>

  (i) Run /maestro services health to check all connections.
```

Omit `Service:` line if unknown. Show only the fix steps that apply.
Show the `/maestro services health` hint only for auth and network errors.

## Fallback: Category-Level Guidance

If no pattern matches, classify the error by category and apply generic guidance.

### auth (exit code 401, 403, or text contains "auth", "token", "credential")

```
[maestro] (x) Authentication error

  Error:   <raw error>
  Cause:   Your credentials may be expired or invalid.

  Fix:
    1. Re-run: /maestro connect <service> to refresh credentials
    2. Check the service's dashboard for token status
    3. Ensure the correct environment variable is set

  (i) Run /maestro services health to check all connections.
```

### network (exit code: any, text contains "connect", "network", "dns", "timeout")

```
[maestro] (x) Network error

  Error:   <raw error>
  Cause:   The service may be unreachable or the request timed out.

  Fix:
    1. Check your internet connection
    2. Visit the service's status page
    3. Retry in 30 seconds

  (i) Run /maestro services health to check all connections.
```

### file (exit code 1 or 2, text contains "no such file", "permission", "EACCES")

```
[maestro] (x) File system error

  Error:   <raw error>
  Cause:   A required file is missing or not accessible.

  Fix:
    1. Check the path exists: ls -la <path>
    2. Check file permissions: chmod u+rw <path>
    3. Re-run setup if a config file is missing: /maestro init
```

### git (text contains "git", "branch", "commit", "merge")

```
[maestro] (x) Git error

  Error:   <raw error>
  Cause:   The repository is in an unexpected state.

  Fix:
    1. Check status: git status
    2. Resolve any conflicts manually
    3. Ensure you are on the correct branch: git branch
```

### generic (no category match)

```
[maestro] (x) Command failed (exit <code>)

  Error:   <raw error>
  Cause:   An unexpected error occurred.

  Fix:
    1. Check the command output above for details
    2. Retry after resolving any reported issues
    3. If the error persists, check the service's documentation
```

## Usage in Other Skills

Call `error_enhancer.enhance(input)` wherever a raw error needs to be surfaced
to the user. The caller provides the raw error; the enhancer returns a formatted
string ready for display.

```
error_enhancer.enhance({
  exit_code: 1,
  stderr: "401 Unauthorized",
  service: "vercel",
  command: "vercel deploy"
})
```

The return value is a formatted block following the Enhanced Error Format above.
Log the enhanced error before displaying it.

## Integration Points

### dev-loop/SKILL.md — Phase 4 (SELF-HEAL)

When a command fails and self-heal cannot fix it, call `error_enhancer.enhance`
before presenting the PAUSE message to the user.

### self-heal-enhanced/SKILL.md

After exhausting recovery strategies, use the enhanced error in the escalation
message so the user sees a clear fix path.

### graceful-degradation/SKILL.md

When logging that a capability has degraded, optionally include the enhanced
error for the root cause.

## Rules

1. Never surface raw stderr to the user without enhancement.
2. Trim error text to 1 line (first line of stderr) in the Error field.
3. Always provide at least one fix step — never leave Fix empty.
4. Do not guess the fix. If uncertain, use the category-level fallback.
5. Follow output-format/SKILL.md: no emoji, text indicators only.
6. Keep lines under 60 characters for terminal readability.
