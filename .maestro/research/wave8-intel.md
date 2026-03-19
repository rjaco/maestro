# Wave 8 Research — Competitive Intelligence & Feature Gaps

**Researcher:** Claude Sonnet 4.6
**Date:** 2026-03-18
**Scope:** What to build next after Waves 6–7

---

## 1. Claude Code v2.1.x — New Capabilities Maestro Has Not Adopted

Source: https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md and https://code.claude.com/docs/en/hooks

### 1.1 Hook Events Now Available That Maestro Does NOT Handle

Claude Code (as of v2.1.78) exposes 21 hook events. Maestro hooks.json covers 10. The 11 not yet handled:

| Event | Since | Can Block? | High-value for Maestro |
|-------|-------|-----------|------------------------|
| `InstructionsLoaded` | v2.1.69 | No | YES — fire whenever CLAUDE.md is loaded; can inject Maestro context into any project that installs the plugin without needing SessionStart overlap |
| `ConfigChange` | v2.1.49 | YES | YES — block or log unauthorized changes to `.claude/settings.json`; enterprise compliance + drift detection |
| `WorktreeCreate` | v2.1.50 | YES | YES — replace default git worktree creation; can run `npm install`, copy `.env`, assign deterministic ports, log to Maestro ledger |
| `WorktreeRemove` | v2.1.50 | No | YES — cleanup: kill dev server processes, log worktree closure to token ledger |
| `SubagentStart` | v2.1.x | No | YES — registry: record spawned subagent IDs in `.maestro/instances/` for the instance-registry skill |
| `PostToolUseFailure` | v2.1.x | No | YES — error-recovery skill trigger: detect tool failures without polling |
| `UserPromptSubmit` | v2.1.x | YES | Partial — prompt-inject-hook.sh already handles this; needs to also inject worktree context |
| `TeammateIdle` | v2.1.x | YES | YES — teammate is idle; Maestro can dispatch next task automatically |
| `TaskCompleted` | v2.1.x | YES | YES — task-completed-hook.sh exists but check: does it advance the story state? |
| `Elicitation` | v2.1.76 | YES | LOW — for MCP servers that request user input; Maestro can auto-respond to known patterns |
| `StopFailure` | v2.1.78 | No | YES — stop-failure-hook.sh exists; verify it handles rate_limit/auth_failed variants |

**Verdict:** `WorktreeCreate`, `WorktreeRemove`, `SubagentStart`, `PostToolUseFailure`, `InstructionsLoaded`, and `ConfigChange` are all achievable with pure bash and are high-impact additions.

### 1.2 Skills Frontmatter Fields Maestro Skills Do Not Yet Use

New frontmatter fields added in v2.1.76 that none of Maestro's SKILL.md files currently use:

```yaml
effort: medium          # Controls model effort: low | medium | high
maxTurns: 10            # Cap runaway skills
disallowedTools:        # Restrict dangerous tools per skill
  - Bash
model: opus-4-6         # Per-skill model override
```

Also: `${CLAUDE_SKILL_DIR}` variable (v2.1.69) lets a SKILL.md reference its own directory. Useful for skills that bundle local templates or scripts.

**Verdict:** High value. The `maxTurns` + `disallowedTools` fields directly address runaway-agent problems Maestro currently handles with heuristics. Add to all critical skills, especially `dev-loop`, `sparc`, `soul`, and `opus-loop`.

### 1.3 `${CLAUDE_PLUGIN_DATA}` Persistent Storage

v2.1.78 added `${CLAUDE_PLUGIN_DATA}` — a plugin-scoped directory that persists across plugin updates. Currently Maestro stores persistent state in `.maestro/` (project-local). For cross-project data (registry, token ledger aggregates, trust scores), `${CLAUDE_PLUGIN_DATA}` is the correct store. No bash changes needed — just update paths in relevant skills.

### 1.4 Agent Frontmatter for Maestro Agents

v2.1.76 allows agents in `agents/` to carry:

```yaml
effort: medium
maxTurns: 10
disallowedTools:
  - Bash
model: opus-4-6
```

Maestro's 6 agents (fixer, implementer, proactive, qa-reviewer, researcher, strategist) should each have `maxTurns` and `effort` tuned per role. The implementer warrants `maxTurns: 30`, the qa-reviewer `maxTurns: 5`, the researcher `disallowedTools: [Write, Edit]` for safety.

### 1.5 `/loop` Command — Cron Scheduling (v2.1.71)

Claude Code added `/loop 5m check the deploy` for recurring prompts. Maestro's opus-daemon.sh does this externally via a bash while-loop. The `/loop` command is a native alternative for lighter orchestration needs that does not require the daemon. Maestro should document `/loop` as an alternative to opus-daemon for simple recurring checks.

### 1.6 HTTP Hooks

hooks.json now supports `"type": "http"` entries that POST JSON to a local URL:

```json
{ "type": "http", "url": "http://localhost:9000/hooks", "timeout": 10 }
```

This enables a lightweight local aggregator daemon (netcat/socat listener or simple Python Flask) to receive all hook events without each hook script needing to be a separate shell process. Maestro could ship an optional `scripts/hook-relay.sh` that starts a socat listener and fans events out. This is the pattern OpenClaw's Gateway uses, reimplemented in 50 lines of bash.

---

## 2. OpenClaw Competitive Gaps — What Maestro Lacks vs OpenClaw

Source: https://docs.openclaw.ai/tools/acp-agents, https://shashikantjagtap.net/openclaw-acp-what-coding-agent-users-need-to-know-about-protocol-gaps/

### 2.1 OpenClaw Architecture (What It Actually Does)

OpenClaw runs Claude Code as a supervised child process via ACP (Agent Client Protocol), which is JSON-RPC over stdio. The Gateway daemon is a WebSocket server that multiplexes multiple ACP sessions. Key capabilities:

- `maxConcurrentSessions: 8` — hard limit, enforced by Gateway
- Sessions have TTL (default 120 minutes) and auto-restart on death
- Each session has a named slot (`-s backend`, `-s frontend`) = named parallel workstreams
- `session/cancel` for graceful shutdown; force-kill if no response
- Process health via `/acp doctor`

**OpenClaw's documented gaps vs Claude Code native:**
- Does NOT call filesystem ACP methods (no unsaved buffer access)
- Does NOT replay session history on reconnect (empty response)
- Does NOT forward `session/request_permission` (yolo mode only)
- Drops MCP server configurations entirely

**Maestro's position:** Maestro does not have these gaps because it uses Claude Code natively. OpenClaw is a compatibility layer with real limitations.

### 2.2 What OpenClaw Has That Maestro Lacks

| Feature | OpenClaw | Maestro | Gap |
|---------|----------|---------|-----|
| Named parallel sessions (`-s frontend`) | Yes — built-in session slots | No — opus-daemon is single-session sequential | HIGH |
| Session TTL + auto-restart | Yes — Gateway manages | Partial — stall-detection in opus-daemon | MEDIUM |
| Multi-model routing per session | Yes — bind Claude/Codex/Gemini per slot | Yes — model-router skill | LOW |
| Persistent session memory across restarts | Yes — session/load | Partial — SessionStart hook injects context | MEDIUM |
| Gateway health endpoint | Yes — `/acp doctor` | No — no health API | LOW |

**Most actionable gap:** Named parallel sessions. `opus-daemon.sh` currently runs one `claude --continue` at a time, serially. It can be extended to spawn multiple `claude --worktree <name> -p <prompt>` processes in parallel using bash `&` + `wait`, each isolated in a git worktree.

---

## 3. "Run Above Claude Code" — Parallel Spawning via bash

Source: https://www.anthropic.com/engineering/building-c-compiler, https://claudefa.st/blog/guide/agents/async-workflows

### 3.1 The Anthropic-Validated Pattern

Anthropic's own C compiler project (with teams of parallel Claudes) uses this exact bash pattern:

```bash
while true; do
  claude --dangerously-skip-permissions \
         -p "$(cat AGENT_PROMPT.md)" \
         --model claude-opus-X-Y &> "logs/agent_${COMMIT}.log"
done
```

Coordination via:
- **File-based locking**: agents claim tasks by creating lock files in `current_tasks/`
- **Git as sync bus**: agents pull, merge, push — git prevents duplicate task claims
- **No daemon needed**: plain bash `&` for background processes, `wait` to collect

### 3.2 What Maestro's opus-daemon.sh Can Adopt

The current `opus-daemon.sh` is single-threaded. The extension to parallel spawning is:

```bash
# In opus-daemon.sh — parallel worker pattern
spawn_worker() {
  local worker_id="$1"
  local story_file="$2"
  local worktree_name="maestro-worker-${worker_id}"

  claude --worktree "$worktree_name" \
         --yes \
         -p "$(cat "$story_file")" \
         --model opus \
         &> "$LOG_DIR/worker-${worker_id}.log" &

  echo $! > "$LOG_DIR/worker-${worker_id}.pid"
}

# Launch N workers, wait for all
for story in $(get_ready_stories); do
  spawn_worker "$NEXT_WORKER_ID" "$story" &
  NEXT_WORKER_ID=$((NEXT_WORKER_ID + 1))
done
wait
```

**Constraints established by research:**
- `claude --worktree <name>` creates an isolated git checkout per worker (v2.1.50+)
- With `--yes`, no permission prompts block the worker
- Each worker gets its own hooks loaded from the worktree (v2.1.78)
- The `WorktreeCreate` hook can run `npm install` / env setup before Claude starts
- Concurrency limit: Anthropic recommends ≤10 parallel agents to avoid API rate limits
- Workers should NOT use `--continue` (that requires a previous session); use `-p` with self-contained prompts

**File-based task claiming** (prevents duplicate work):
```bash
# Worker claims a story by creating a lock file
CLAIM_FILE="$MAESTRO_DIR/stories/in-progress/$(basename "$STORY").lock"
if ( set -C; > "$CLAIM_FILE" ) 2>/dev/null; then
  # We own this story
  run_story "$STORY"
  rm "$CLAIM_FILE"
fi
```

### 3.3 OpenClaw Gateway Without Node.js

OpenClaw's Gateway is a WebSocket multiplexer. Maestro can achieve the same with:
- **socat** or **nc** for the listener
- **HTTP hooks** posting to `http://localhost:PORT/events`
- A `scripts/hook-relay.sh` that fans out to Telegram, desktop notifications, and the log bus

This is 50–100 lines of bash, not a Node.js service.

---

## 4. Multi-Repo Orchestration — Shell-Only Patterns

Source: https://github.com/ruvnet/ruflo/wiki/GitHub-Integration, https://github.com/ruvnet/ruflo

### 4.1 How Ruflo Does It

Ruflo's `multi-repo-swarm` agent takes `--repos "api-gateway,user-service,auth-service"` and creates PRs across all repos using the `gh` CLI. The agent is invoked via:

```bash
npx claude-flow agent spawn multi-repo-swarm \
  --task "Synchronize API changes across microservices" \
  --repos "api-gateway,user-service,auth-service" \
  --create-prs
```

The actual implementation uses the `gh` CLI for PR creation and git for coordination. This is replicable entirely in bash.

### 4.2 Maestro Multi-Repo Pattern (Shell-Only)

A `multi-repo` skill or command can implement the same using:

```bash
# .maestro/multi-repo-config.yaml lists the repos
repos:
  - path: ../api-gateway
    role: backend
  - path: ../user-service
    role: service
  - path: ../web-app
    role: frontend

# For each repo:
# 1. cd into it
# 2. git worktree add for isolation
# 3. spawn claude --worktree --yes -p "<task with repo context>"
# 4. collect results
# 5. gh pr create --repo <owner/repo> --title "..." --body "..."
```

**Key implementation points:**
- Each repo gets its own `claude --worktree` session (isolation)
- `gh pr create` handles cross-repo PRs natively
- A shared `coordination.md` file in a neutral location (or a temp dir) acts as the sync bus
- `WorktreeCreate` hook fires per repo, setting up the env correctly
- The `merge-coordinator` skill already handles conflicts; extend it to cross-repo

**Concretely needed:**
1. `commands/multi-repo.md` — orchestrates parallel claude sessions per repo
2. `.maestro/multi-repo-config.yaml` schema — lists repos + roles
3. A `scripts/multi-repo-spawn.sh` — iterates repos, spawns workers, collects results

---

## 5. Self-Test Infrastructure — Functional Hook Tests

Source: https://blakecrosley.com/blog/claude-code-hooks-tutorial, https://github.com/anthropics/claude-code/issues/6403

### 5.1 Current Smoke Test Gaps

`tests/smoke-test.sh` validates:
- Hook scripts exist and are executable
- SKILL.md has valid frontmatter
- Mirror sync between `skills/` and `plugins/maestro/skills/`
- Command frontmatter
- Agent frontmatter
- JSON validity

It does NOT validate:
- That hook scripts correctly parse stdin JSON
- That exit codes are correct for known inputs
- That hooks produce the expected stdout JSON
- That blocking hooks actually block (exit 2 vs exit 1 confusion is a documented common bug)

### 5.2 Functional Hook Test Pattern

The stdin piping pattern is well-established and works today:

```bash
# Test a hook with a mock payload
echo '{"session_id":"test","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"rm -rf /"}}' \
  | ./hooks/prompt-inject-hook.sh
echo "Exit: $?"
```

A `tests/hook-test.sh` can implement a full suite:

```bash
# Test: permission-request-hook blocks known bad commands
run_hook_test() {
  local name="$1"
  local hook="$2"
  local payload="$3"
  local expected_exit="$4"
  local expected_stdout_pattern="${5:-}"

  local stdout
  stdout=$(echo "$payload" | "$hook" 2>/dev/null)
  local actual_exit=$?

  if [[ "$actual_exit" -eq "$expected_exit" ]]; then
    if [[ -n "$expected_stdout_pattern" ]] && ! echo "$stdout" | grep -q "$expected_stdout_pattern"; then
      echo "[FAIL] $name: stdout missing pattern: $expected_stdout_pattern"
      return 1
    fi
    echo "[PASS] $name"
    return 0
  else
    echo "[FAIL] $name: expected exit $expected_exit, got $actual_exit"
    return 1
  fi
}

# Example test cases
HOOKS_DIR="$(dirname "$0")/../hooks"

run_hook_test \
  "session-start: no-op when no DNA" \
  "$HOOKS_DIR/session-start-hook.sh" \
  '{"session_id":"t","cwd":"/tmp","hook_event_name":"SessionStart"}' \
  0

run_hook_test \
  "stop-failure: exits 0 always" \
  "$HOOKS_DIR/stop-failure-hook.sh" \
  '{"session_id":"t","hook_event_name":"StopFailure","error_type":"rate_limit"}' \
  0
```

### 5.3 What Tests to Add First (Priority Order)

1. **session-start-hook.sh** — test: exits 0 when no DNA; exits 0 and emits systemMessage when DNA present
2. **permission-request-hook.sh** — test: allows known-safe commands; blocks known-dangerous patterns
3. **notification-hook.sh** — test: exits 0; optionally emits Telegram call
4. **stop-hook.sh** — test: exits 0; does not block stop event
5. **prompt-inject-hook.sh** — test: injects correct context; does not corrupt prompt
6. **post-tool-use-hook.sh** — test: records tool use in ledger; exits 0 on non-Write tools

### 5.4 CI Integration

The test file should be invocable as:
```bash
./tests/hook-test.sh        # run all
./tests/hook-test.sh <name> # run one
```

And integrate into any CI workflow (GitHub Actions step: `bash ./tests/hook-test.sh`).

---

## 6. Competitor Matrix — After Waves 6–7

| Feature | OpenClaw | Ruflo v3.5 | Maestro (after Wave 7) | Gap Priority |
|---------|----------|------------|------------------------|-------------|
| Hook events covered | N/A (not a plugin) | 17 hooks | 10/21 events | HIGH |
| Parallel agent spawning | Yes (Gateway, 8 sessions) | Yes (workers + channels) | No (serial daemon) | HIGH |
| Skills frontmatter (effort/maxTurns) | N/A | N/A | Not used | HIGH |
| Functional hook tests | None | Pre/post task hooks | None | HIGH |
| Multi-repo coordination | No | Yes (multi-repo-swarm) | No | MEDIUM |
| WorktreeCreate/Remove hooks | N/A | N/A | Not handled | MEDIUM |
| Persistent plugin data (CLAUDE_PLUGIN_DATA) | N/A | N/A | Not used | MEDIUM |
| HTTP hook relay | Yes (WebSocket Gateway) | N/A | No | LOW |
| Named parallel sessions | Yes (-s flag) | Yes (workers) | No | HIGH |
| Self-test suite | None | None | Structural only | HIGH |
| `/loop` cron integration | Via scheduler | Via cron workers | External daemon only | LOW |
| Agent frontmatter (model/effort) | N/A | N/A | Not used | MEDIUM |

---

## 7. Prioritized Feature List for Wave 8

Ranked by: (impact × achievability with bash+markdown) / effort.

### Tier 1 — High Impact, Low Effort (Pure bash + markdown changes)

**W8-01: Skills/Agents Frontmatter Hardening**
- Add `maxTurns`, `effort`, `disallowedTools` to all 6 agents
- Add `maxTurns`, `effort` to the 10 highest-risk skills (dev-loop, sparc, opus-loop, soul, stream-chain, swarm-topologies, doom-loop, sparc, delegation, background-workers)
- Zero new files needed; pure SKILL.md/agent.md edits
- Prevents runaway agents cold

**W8-02: Functional Hook Tests (`tests/hook-test.sh`)**
- New file: `tests/hook-test.sh`
- Tests all 13 existing hook scripts with mock stdin JSON
- Extends `tests/smoke-test.sh` to call hook-test suite
- Pattern is fully established by research (see §5)
- Unblocks confident development of new hooks

**W8-03: Missing Hook Events — WorktreeCreate + WorktreeRemove**
- New: `hooks/worktree-create-hook.sh` — env setup (copy `.env`, run install, assign port, log to Maestro)
- New: `hooks/worktree-remove-hook.sh` — kill dev server, log closure
- Add entries to `hooks/hooks.json`
- Pattern fully specified by https://github.com/tfriedel/claude-worktree-hooks (§3.1)
- Enables the parallel spawning pattern in Tier 2

**W8-04: Missing Hook Events — SubagentStart + PostToolUseFailure + InstructionsLoaded**
- New: `hooks/subagent-start-hook.sh` — write agent ID to `.maestro/instances/` for registry
- New: `hooks/post-tool-use-failure-hook.sh` — log failure, increment error counter for error-recovery skill
- New: `hooks/instructions-loaded-hook.sh` — inject Maestro context into any session loading CLAUDE.md
- All three are observability-only (no blocking); safe additions
- Brings hook coverage to 14/21

**W8-05: ConfigChange Hook**
- New: `hooks/config-change-hook.sh` — can block unauthorized writes to project settings; log all config changes
- Directly addresses the anti-drift + security-drift skills
- Add `ConfigChange` entry to `hooks/hooks.json`

### Tier 2 — High Impact, Medium Effort

**W8-06: Parallel Worker Spawning in opus-daemon.sh**
- Extend `scripts/opus-daemon.sh` with a `--parallel N` flag
- Uses `claude --worktree <name> -p <prompt> &` pattern
- File-based story claiming (lock files in `.maestro/stories/in-progress/`)
- `wait` at end of each iteration collects all workers
- New: `scripts/parallel-spawn.sh` for standalone use
- Requires: WorktreeCreate hook (W8-03) to be in place first

**W8-07: Multi-Repo Orchestration Command**
- New: `commands/multi-repo.md` — reads `.maestro/multi-repo-config.yaml`, iterates repos, spawns per-repo claude sessions, creates PRs via `gh`
- New: `.maestro/multi-repo-config.yaml` schema documented in command
- Does not require a daemon; runs to completion
- Depends on: parallel worker pattern (W8-06)

**W8-08: `${CLAUDE_PLUGIN_DATA}` Migration for Cross-Project State**
- Update `token-ledger`, `instance-registry`, `squad-registry`, `trust` skills to use `${CLAUDE_PLUGIN_DATA}` for persistent plugin-level state
- Pure path variable substitution in SKILL.md files
- Enables Maestro to accumulate data across projects

### Tier 3 — Lower Impact or Waiting on Tier 1+2

**W8-09: HTTP Hook Relay (`scripts/hook-relay.sh`)**
- Lightweight socat listener that receives all hook events via HTTP hooks
- Fans out to: Telegram, log file, future webhook endpoints
- 50–100 lines bash; replaces separate Telegram calls in each hook
- Requires: HTTP hook support (already in Claude Code); medium complexity

**W8-10: Agent Frontmatter for Agents**
- Update `agents/*.md` with `effort:`, `maxTurns:`, `disallowedTools:` per role
- Low effort but depends on verifying the fields work as expected

---

## 8. Technical Patterns Worth Noting

### Pattern: File-Based Task Claiming (Anthropic-validated)

From the C compiler project. Workers race to create a lock file using bash's `set -C` (noclobber) flag. The first writer wins. No database needed:

```bash
if ( set -C; echo "$$" > "$CLAIM_FILE" ) 2>/dev/null; then
  # This worker owns the task
fi
```

### Pattern: WorktreeCreate Hook for Environment Bootstrap

From https://github.com/tfriedel/claude-worktree-hooks. The hook must print ONLY the worktree path to stdout — any extra output causes Claude to hang silently. Pattern:

```bash
WORKTREE_PATH=".claude/worktrees/${NAME}"
git worktree add -b "worktree-${NAME}" "$WORKTREE_PATH" HEAD >/dev/null 2>&1
# Do env setup here (all output to files or /dev/null)
echo "$WORKTREE_PATH"  # ONLY this on stdout
```

### Pattern: Mock JSON Testing for Hooks

```bash
echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"rm -rf /"}}' \
  | ./hooks/permission-request-hook.sh
```

Exit code 2 = blocking. Exit code 0 = allow. Any other exit = warn-only. This is the complete test oracle.

### Anti-Pattern: Conflating Exit Code 1 and Exit Code 2

Documented bug in multiple community reports. Exit code 1 is a non-blocking error (warn only). Exit code 2 is the blocking exit. Many hook scripts use `exit 1` thinking they are blocking — they are not. Maestro's `tests/hook-test.sh` must verify exit 2 for all hooks that claim to block.

---

## 9. SEO/Ecosystem Notes

- The Claude Code plugin marketplace is actively growing; Maestro should add more descriptive `description` and `tags` in `plugin.json` to improve discoverability
- The community "Claude Code Plugins Plus Skills" repo (340+ plugins) is a signal that the ecosystem is fragmenting; Maestro's all-in-one positioning is a differentiator worth calling out in README
- OpenClaw's CVE-2026-25253 (CVSS 8.8, RCE via WebSocket origin bypass) is public. Maestro's bash-native architecture avoids the entire attack surface. Worth a one-liner in FEATURES.md under Security.

---

## Sources

- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks)
- [Claude Code CHANGELOG](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md)
- [OpenClaw ACP Docs](https://docs.openclaw.ai/tools/acp-agents)
- [acpx — Headless ACP CLI](https://github.com/openclaw/acpx)
- [OpenClaw ACP Protocol Gaps Analysis](https://shashikantjagtap.net/openclaw-acp-what-coding-agent-users-need-to-know-about-protocol-gaps/)
- [Ruflo GitHub](https://github.com/ruvnet/ruflo)
- [Ruflo GitHub Integration Wiki](https://github.com/ruvnet/ruflo/wiki/GitHub-Integration)
- [Ruflo v3.5.0 Release](https://github.com/ruvnet/ruflo/issues/1240)
- [Anthropic: Building a C Compiler with Parallel Claudes](https://www.anthropic.com/engineering/building-c-compiler)
- [Ona: How to Parallelize Claude Code](https://ona.com/stories/parallelize-claude-code)
- [claude-worktree-hooks](https://github.com/tfriedel/claude-worktree-hooks)
- [Claude Code Hooks Tutorial](https://blakecrosley.com/blog/claude-code-hooks-tutorial)
- [ccswarm: Multi-agent orchestration](https://github.com/nwiizo/ccswarm)
- [OpenClaw vs Claude Code 2026](https://claudefa.st/blog/tools/extensions/openclaw-vs-claude-code)
- [Claude Code Async Workflows](https://claudefa.st/blog/guide/agents/async-workflows)
- [Claude Code Releasebot March 2026](https://releasebot.io/updates/anthropic/claude-code)
