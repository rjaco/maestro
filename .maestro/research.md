# Wave 10 Research: Gaps, Opportunities, and Acquisition Readiness

**Research date:** 2026-03-19
**Scope:** Acquisition readiness, README quality, npm publishing, test coverage, performance, community readiness
**Sources:** Claude Code docs (code.claude.com), codebase analysis, companion package.json

---

## Summary

Maestro is feature-dense and technically sound but has several gaps that would matter to Anthropic and to the open-source community. The highest-impact items are: (1) the plugin's hooks.json does not register the newer hook events Claude Code now natively supports, (2) the companion is unpublishable to npm as-is, (3) the agent.ts file uses `context.ts`-style SDK access that does not align with the current Claude Code sub-agent system, (4) the README undersells what Maestro actually does, and (5) five critical TypeScript modules have zero test coverage.

---

## 1. Acquisition Readiness: What Anthropic Would Care About

### What Claude Code natively supports now (verified against docs)

| Native Claude Code Feature | Maestro's Coverage |
|---|---|
| Skills (SKILL.md, frontmatter, `context: fork`, `allowed-tools`) | Covered — Maestro uses SKILL.md across 138 skills |
| Custom subagents (`.claude/agents/*.md`, `tools`, `model`, `memory`, `hooks`, `permissionMode`) | Partial — Maestro has 6 agents but does not use `memory:`, `isolation: worktree`, or `background: true` frontmatter |
| Hooks (28 events, `type: command/http/prompt/agent`) | Partial — Maestro registers 12 hooks but misses 16 native events |
| Plugins (`.claude-plugin/plugin.json`, marketplace) | Covered |
| Bundled skills (`/batch`, `/simplify`, `/loop`, `/debug`) | Maestro duplicates these without acknowledging overlap |
| `$ARGUMENTS[N]`, `${CLAUDE_SKILL_DIR}`, `${CLAUDE_SESSION_ID}` substitutions | Not used — Maestro uses manual `$ARGUMENTS` but ignores positional and session vars |
| `disable-model-invocation: true` / `user-invocable: false` | Not used — all skills are model-invocable by default |
| LSP server registration in plugins | Not present |
| `settings.json` in plugin root (set default agent) | Not present |
| `context: fork` with `agent:` field for subagent delegation | Not present in skills |

### What would make Anthropic want to acquire this

Anthropic's native bundled skills (`/batch`, `/simplify`, `/loop`) are generic. Maestro's value is the **opinionated orchestration layer** on top: progressive trust, QA-reviewer-as-separate-agent, self-heal loop, session memory, cost forecasting, the Magnum Opus deep interview. These are not things Anthropic would build natively because they are product-development _methodology_, not tooling infrastructure.

**The gap is that Maestro does not use the most powerful native primitives:**

- **Agent persistent memory** (`memory: project` in agent frontmatter) — Maestro builds its own SQLite memory in the companion, but the plugin's agents have no `memory:` field. Every agent definition in `agents/` could have `memory: project` to give it cross-session institutional knowledge natively.
- **Subagent `isolation: worktree`** — Maestro's delegation hook tries to enforce worktree isolation via a shell script. The native `isolation: worktree` frontmatter on agent definitions does this declaratively and is architecturally cleaner.
- **`background: true` on agents** — Maestro's worker pool in the companion reimplements what `background: true` does natively.
- **The `PreToolUse` `type: agent` hook** — Maestro uses `type: command` shell scripts for all hooks. The `type: agent` hook can spawn a subagent that reads context and makes decisions. This would be more reliable than bash parsing YAML frontmatter.
- **Hook events not registered:** `UserPromptSubmit`, `PostToolUseFailure`, `SubagentStart`, `SubagentStop`, `ConfigChange`, `InstructionsLoaded`, `Elicitation`, `ElicitationResult`, `SessionEnd` — nine events Maestro ignores that could enable richer observability and anti-drift enforcement.

**The one thing Anthropic cannot replicate without acquiring Maestro:** the `opus-loop` deep interview plus milestone-driven autonomous loop with live conversation channel. This is genuinely novel. The 10-dimension product interview + 8 parallel research agents + milestone evaluator is not in any native Claude Code feature.

---

## 2. README and Documentation

### Current state

- Version badge says `1.4.0`, skills badge says `128` — actual count appears to be 138 (per dna.md). The badges are stale.
- Commands table in README lists 21 commands, but FEATURES.md lists 42+ commands. The README is missing approximately half the commands.
- No architecture diagram showing the three-layer system visually.
- No GIF or screenshot. The README is wall-of-text for a product that has visual dashboards.
- No "What's New" or changelog call-out for recent waves.
- The "Progressive Trust" table and "Cost Tracking" sections are present but buried. These are strong differentiators.
- "Companion" (17 TypeScript modules, voice, Telegram, worker pool) is not mentioned at all in the README.
- The marketplace.json `owner.url` points to `https://github.com/anthropics/maestro-orchestrator` — this is aspirational. The actual repo URL (via plugin.json `homepage`) is `https://github.com/rodrigo-deepneuron/maestro`.

### Specific gaps

1. Badges: skills count (128 vs 138), commands count (42 vs 43), hooks count, companion mention.
2. The companion (Telegram bot, voice, worker pool) is a major differentiator that is absent from the README entirely.
3. No install-from-git section for contributors who want to work from source before marketplace availability.
4. The `demo` command and `magnum-opus` are the two most impressive features; they deserve dedicated sections with step-by-step examples, not just table rows.
5. No links to FEATURES.md or CONTRIBUTING.md from the README.

---

## 3. npm Publishing Readiness

### Current state of `companion/package.json`

```json
"name": "maestro-companion",
"version": "0.1.0",
"bin": { "maestro-companion": "./dist/index.js" },
"main": "dist/index.js"
```

### Gaps

| Issue | Severity | Detail |
|---|---|---|
| No `files` field | High | `npm publish` will upload everything including `node_modules/`, `store/`, `workspace/`. Must add `"files": ["dist/", "scripts/"]`. |
| `dist/` is not built | High | `tsc` build is required before publish. `npm publish` should run `build` first via `"prepublish": "npm run build"`. |
| No `exports` field | Medium | Node ESM resolution requires `"exports": { ".": "./dist/index.js" }` for proper module resolution in Node 20+. |
| `main` points to `dist/index.js` but `type: "module"` — no `module` field | Low | The `main` field works, but `exports` is more correct for ESM packages. |
| Binary shebang present (`#!/usr/bin/env node`) | Good | Already in `src/index.ts`. |
| No `publishConfig` | Low | Should add `"publishConfig": { "access": "public" }` for scoped packages, or confirm unscoped name is available. |
| `@anthropic-ai/claude-agent-sdk: ^0.1.0` | High | This package version may not be on npm public registry. Must verify before publishing. |
| `better-sqlite3` requires native compilation | High | Binary dependency. Must include `"optionalDependencies"` pattern or document that `node-gyp` is required. |
| No `.npmignore` or refined `files` | High | Without `files`, `companion/.env`, `store/companion.db`, audit logs would be published. |
| `bun` used in dev scripts, `node` in bin | Medium | README must clarify bun is only for dev; production `npm install` + `node dist/index.js` must work without bun. |
| No changelog in companion | Low | npm consumers expect a CHANGELOG.md or releases. |
| Missing `repository` field | Low | `package.json` has no `repository` field, required for npm homepage link. |

### Build pipeline gap

There is no CI/CD workflow file (`.github/workflows/`) for the companion. npm publishing requires at minimum a release action that runs `tsc`, runs vitest, and then `npm publish`. This is completely absent.

---

## 4. Testing Gaps

### Companion test coverage (78 tests across 6 files)

| Module | Test file | Tests | Critical paths NOT covered |
|---|---|---|---|
| `agent.ts` | None | 0 | SDK fallback to CLI, session persistence, cost extraction |
| `memory.ts` | None | 0 | `saveMemory`, `buildMemoryContext`, `runDecaySweep`, FTS vs LIKE branch |
| `soul.ts` | None | 0 | `loadSoul` path resolution, PLUGIN_DATA fallback, cache invalidation |
| `db.ts` | None | 0 | Session get/save, connection close, table creation |
| `config.ts` | None | 0 | Env file parsing, fallback values, `allowedChatIds` split |
| `channels/telegram.ts` | None | 0 | Message routing, typing indicator, voice buffer send |
| `env.ts` | `env.test.ts` | ~5 | Covered |
| `formatter.ts` | `formatter.test.ts` | ~10 | Covered |
| `workers/pool.ts` | `pool.test.ts` | ~12 | Covered |
| `workers/coordinator.ts` | `coordinator.test.ts` | ~11 | Covered |
| `voice/pipeline.ts` | `voice.test.ts` | ~20 | Covered |
| `voice/stt.ts` | `voice.test.ts` | ~8 | Covered |
| `voice/tts.ts` | `voice.test.ts` | ~12 | Covered |
| `state.ts` | `state.test.ts` | ~20 | Covered |

**The three highest-risk untested paths:**
1. `agent.ts: runWithAgentSDK` — the SDK streaming loop that extracts session ID and cost. A regression here would silently lose session continuity.
2. `memory.ts: buildMemoryContext` — the FTS5 vs LIKE fallback branch. If FTS5 is unavailable (common on some SQLite builds), the fallback must work correctly. Currently untested.
3. `agent.ts: runWithCLI` — the fallback when SDK fails. This is the disaster-recovery path and has zero tests.

### Plugin test coverage (shell scripts)

The plugin has no automated tests beyond `scripts/smoke-test.sh`. Critical paths with no coverage:

1. `hooks/delegation-hook.sh` — the YAML parser built in bash (the `yaml_val()` function). If a value contains a colon, the grep breaks. No test.
2. `hooks/stop-hook.sh` — session isolation logic (compares `state_session_id` vs `current_session_id`). Edge cases around empty session IDs are untested.
3. `hooks/branch-guard.sh` — the branch protection logic. No test for the case where `.git/HEAD` is missing or detached HEAD.
4. `scripts/validate-hooks.sh` — the hook validator script. It validates hooks but is not itself tested.

---

## 5. Performance

### Shell script bottlenecks

| Script | Bottleneck | Severity |
|---|---|---|
| `hooks/delegation-hook.sh` | Forks `jq` twice (once for `file_path`, once for `tool_name`) and runs `sed` + `grep` for YAML parsing on every `PreToolUse` event | Medium — fires on every Edit/Write. At high velocity this adds ~5-15ms per tool call. |
| `hooks/stop-hook.sh` | Reads entire state file with `cat`, then runs multiple `sed` + `grep` passes for YAML parsing | Low — only fires on Stop events. |
| `hooks/session-start-hook.sh` | Runs multiple `jq` forks + `grep` chains at session start | Low — only fires once per session. |
| `hooks/opus-loop-hook.sh` (263 lines) | Largest hook. Reads multiple files, parses YAML, forks multiple subprocesses | Medium — fires on every Stop in opus mode. |

**Root cause:** Every hook that parses YAML uses a bespoke `yaml_val()` bash function that forks `grep` and `sed`. This is unavoidable in pure bash, but the delegation-hook fires on every Edit/Write tool call. At 100+ tool calls per Magnum Opus session, this adds up.

**Fix options (in order of effort):**
- Cache the parsed YAML in an env var or temp file across invocations (low effort).
- Rewrite the highest-frequency hooks in Python/Node (medium effort, adds dependency).
- Use `type: agent` hook for delegation enforcement instead of shell script (best long-term, removes bash parsing entirely).

### TypeScript/companion bottlenecks

| Module | Issue |
|---|---|
| `memory.ts: buildMemoryContext` | Runs up to 4 separate SQLite queries per message (FTS search, recent recall, access update). Could be one query with a UNION. |
| `workers/pool.ts` | The `cleanupWorkerHistory()` function iterates the full worker map on every worker completion. At 100+ workers, this is O(n). |
| `agent.ts: runWithAgentSDK` | The SDK streaming loop has no timeout. A hung SDK call blocks the Telegram response indefinitely. |

---

## 6. Community Readiness

### What exists

- `CONTRIBUTING.md` — Present and detailed. Covers skills, agents, profiles, squads, commands, naming conventions, PR process. Good quality.
- `.github/ISSUE_TEMPLATE/bug_report.md` — Present. Asks for the right info.
- `.github/ISSUE_TEMPLATE/feature_request.md` — Present (seen in glob, not read).
- `.github/PULL_REQUEST_TEMPLATE.md` — Present.
- `squads/CONTRIBUTING.md` — Present (separate squad contribution guide).

### What is missing

| Gap | Priority | Detail |
|---|---|---|
| No skill development tutorial | High | CONTRIBUTING.md says "create a directory and add SKILL.md" but gives no worked example of a non-trivial skill. New contributors need a "your first skill" walkthrough. |
| No test harness for skills | High | CONTRIBUTING.md says "there are no automated tests" — this is fine for simple skills but is a barrier for contributions to critical skills like dev-loop. |
| No CHANGELOG for plugin | Medium | The repo has CHANGELOG.md but it appears to track waves, not semver releases. npm consumers and marketplace users need a conventional changelog. |
| No `SECURITY.md` | Medium | Standard for any plugin that touches file system and git. Should document what data Maestro reads, what it never does (e.g., exfiltrate secrets). |
| No skill packs published | Medium | `skills/skill-pack/SKILL.md` exists but no community packs have been published to demonstrate the mechanism. A demo pack would bootstrap the ecosystem. |
| Companion has no setup script that works without bun | Medium | `scripts/setup.ts` requires bun. The npm-published version needs a `node` equivalent. |
| No Discord or discussion forum link | Low | Community questions currently go to GitHub Issues. |
| `CONTRIBUTING.md` says "no automated tests" but pool.test.ts, state.test.ts, etc. now exist | Low | The contributing guide is out of date — it should mention the companion's vitest suite and encourage contributors to add tests for new modules. |

---

## Competitor Matrix (Claude Code Plugin/Extension Space)

| Feature | Maestro | Continue.dev | Cody (Sourcegraph) | Copilot Workspace |
|---|---|---|---|---|
| Multi-agent orchestration | Yes (6 agents, 7 squads) | No | No | No |
| Autonomous multi-milestone build | Yes (Magnum Opus) | No | No | Limited |
| Plugin marketplace | Yes | No | No | No |
| Progressive trust system | Yes | No | No | No |
| Kanban integration | Yes (4 providers) | No | No | No |
| Second brain / knowledge base | Yes | No | No | No |
| Voice interface | Yes (Telegram bot) | No | No | No |
| Cost tracking + forecasting | Yes | No | No | No |
| TDD enforcement | Yes | No | No | No |
| Self-healing loop | Yes | No | No | No |

---

## Anti-Patterns Observed

1. **Stale badge counts** — README badges show 128 skills/42 commands but dna.md says 138 skills. Every wave adds skills without updating the source-of-truth badges.

2. **Bash YAML parser running on hot path** — The `yaml_val()` function is copy-pasted across 5+ hook scripts. It works for simple cases but breaks silently on values containing colons, quotes, or multi-line values. This is a reliability risk.

3. **`companion/package.json` has no `files` field** — Will publish `node_modules/` and `store/` if `npm publish` is run naively.

4. **`marketplace.json` has aspirational GitHub URL** — Points to `https://github.com/anthropics/maestro-orchestrator` which does not exist. This will cause 404s for anyone who clicks "source" in the marketplace.

5. **`agent.ts` passes `allowDangerouslySkipPermissions: true`** to every worker — including the companion's chat queries, not just build workers. This means casual Telegram conversations run with full bypass permissions. Should be limited to `workers/pool.ts` only.

6. **README and FEATURES.md are out of sync** — FEATURES.md lists 42 commands; README lists 21. CONTRIBUTING.md says there are no automated tests, but there are 78. Any new contributor reads stale information.

---

## Prioritized Action List for Wave 10

**P0 — Blocks npm publish or creates security risk**
1. Add `files` field to `companion/package.json` (prevents secrets/node_modules upload)
2. Remove `allowDangerouslySkipPermissions: true` from `agent.ts` chat queries (security)
3. Fix `marketplace.json` owner URL from aspirational to actual repo

**P1 — Acquisition readiness and technical quality**
4. Add `memory: project` to all 6 agent definitions (uses native Claude Code memory)
5. Add `isolation: worktree` to implementer agent definition (replaces delegation hook enforcement)
6. Register missing hook events: `UserPromptSubmit`, `PostToolUseFailure`, `SubagentStart`, `SubagentStop`, `SessionEnd`
7. Add `repository` field to `companion/package.json`
8. Add `exports` field to `companion/package.json` for proper ESM resolution

**P2 — Test coverage for highest-risk paths**
9. Add tests for `agent.ts` (SDK streaming, CLI fallback, session persistence)
10. Add tests for `memory.ts` (FTS path, LIKE fallback, decay sweep)
11. Add tests for `soul.ts` (path resolution, PLUGIN_DATA, cache)

**P3 — README and documentation**
12. Update all badge counts (138 skills, 43+ commands, 12+ hooks)
13. Add Companion section to README (Telegram bot, voice, worker pool)
14. Add architecture diagram (ASCII or Mermaid) showing three-layer system
15. Update CONTRIBUTING.md to mention companion test suite
16. Fix README commands table to show full 42-command set or link to FEATURES.md

**P4 — Performance**
17. Cache YAML parse result in delegation-hook.sh (single `jq` pass, store in temp file)
18. Add timeout to `agent.ts` SDK streaming (guard against hung calls blocking Telegram)
19. Consolidate `memory.ts` SQLite queries (UNION instead of 4 separate queries)
