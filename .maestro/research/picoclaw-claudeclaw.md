# PicoClaw, ClaudeClaw, and Lightweight OpenClaw Alternatives

**Research date:** 2026-03-19
**Sources:** github.com/sipeed/picoclaw, github.com/earlyaidopters/claudeclaw, github.com/moazbuilds/claudeclaw, qwibitai/nanoclaw, zeroclaws.io, pico-claw.com, picoclaw.dev, local claudeclaw.md (repo)

---

## 1. What Is PicoClaw?

There are at least **three distinct things** called "PicoClaw" in the ecosystem. This disambiguation is critical:

### A. sipeed/picoclaw (canonical lightweight alternative)
- An open-source Go binary written by Sipeed (embedded hardware company)
- Self-described: "ultra-lightweight personal AI Assistant inspired by NanoBot, refactored from the ground up in Go through a self-bootstrapping process"
- 87% Go, supporting TypeScript and shell scripts
- Targets $10 hardware (Raspberry Pi, LicheeRV-Nano, old Android via Termux)
- Supports 12+ chat platforms via a `gateway` command
- Source: https://github.com/sipeed/picoclaw
- Also mirrored/forked at https://github.com/Az0xel/picoclaw-

### B. picoclaw.dev (managed SaaS — DIFFERENT product)
- Managed hosting platform by "Usto AI"
- "Deploy your AI chatbot on Telegram or Discord in under 1 minute"
- No local install — cloud-hosted bots with user's own API key
- Paid tiers: $0 trial / $12 / $19 / $39 per month
- NOT an OpenClaw alternative in the local-daemon sense
- Source: https://picoclaw.dev/

### C. pico-claw.com (documentation site for sipeed/picoclaw)
- Documentation wrapper for sipeed/picoclaw
- Installation, config reference, quick start

**For Maestro purposes, "PicoClaw" = sipeed/picoclaw (option A).**

---

## 2. How PicoClaw Differs from OpenClaw

| Dimension | OpenClaw | PicoClaw (sipeed) |
|-----------|----------|-------------------|
| Language | TypeScript / Node.js | Go |
| Memory (idle) | ~1.2 GB | <10 MB |
| Cold start | ~8 seconds | <1 second |
| Binary size | ~800 MB | ~50 MB |
| Target hardware | Mac Mini+ ($599) | Any Linux board (~$10) |
| Config file | JSON5 (`openclaw.json`) | YAML (`config.json`) |
| Dependency count | 70+ | Minimal (single binary) |
| Codebase | ~500k lines | Small enough to read |
| Channels | 30+ via plugin marketplace | 12+ built-in |
| Architecture | Gateway + daemon + web UI + TUI + macOS app | Single binary, two modes |

OpenClaw has an acknowledged security track record issue: CVE-2026-25253 (one-click RCE) and CVE-2026-26327 (auth bypass) were active in early 2026. 41.7% of ClawHub skills contain vulnerabilities per ZeroClaw's analysis.

---

## 3. How PicoClaw Achieves Lightweight Design

Five concrete mechanisms:

1. **Go instead of Node.js**: Compiled binary, no JIT warmup, no V8 runtime overhead. The runtime is the binary — no interpreter to initialize.

2. **Single binary distribution**: One self-contained executable across x86_64, ARM64, MIPS, RISC-V, LoongArch. No `node_modules/`, no package manager required at runtime.

3. **Two-mode architecture**: `agent` mode (CLI, zero server overhead) and `gateway` mode (server, only runs when needed). No always-on web UI or TUI unless explicitly started.

4. **No plugin marketplace**: Channels are built-in modules, not downloaded plugins. No ClawHub-style marketplace to load.

5. **Go garbage collector tradeoff**: PicoClaw sits between ZeroClaw (Rust, ~4 MB, no GC) and OpenClaw (Node.js, ~1.2 GB). Go gives a middle ground — compiled but with GC, which is why it lands at <10–20 MB rather than ~4 MB.

**Comparison with ZeroClaw (Rust) — the most extreme alternative:**
- ZeroClaw: ~4 MB RAM, <10ms cold start, single binary, trait-driven extensibility
- PicoClaw: ~10–20 MB RAM, <1s cold start, single binary, direct repo modification for extensions
- PicoClaw is the more approachable option; ZeroClaw is for production edge deployments

---

## 4. PicoClaw Architecture

Two operating modes:

```
Agent Mode (CLI):
  User → CLI stdin → picoclaw agent → LLM API → stdout

Gateway Mode (server):
  Telegram/Discord/QQ/etc.
       ↓
  picoclaw gateway (long-polling or webhook)
       ↓
  Channel adapter (built-in, not plugins)
       ↓
  LLM API (OpenRouter, Anthropic, OpenAI, Gemini, Zhipu)
       ↓
  Response → channel
```

Config stored in `~/.picoclaw/config.json` (JSON format, despite YAML mentioned in some docs).

Supported LLM providers: OpenRouter, Zhipu, Anthropic, OpenAI, Gemini (configurable via API key in config).

Supported channels: Telegram, Discord, QQ, DingTalk, LINE, WeCom, Matrix, IRC, WeChat (12+ total).

Daemon/service setup: Run `picoclaw gateway` as a systemd service with auto-restart:
```ini
[Service]
ExecStart=/usr/local/bin/picoclaw gateway
Restart=on-failure
RestartSec=5
```

Cron-style expressions for scheduled tasks are supported natively.

---

## 5. Messaging / Companion Mode

PicoClaw's companion mode is the `gateway` command. Configuration is purely file-based (no pairing codes, no OAuth flows):

```yaml
# config.yaml (pico-claw.com docs format)
api_key: "sk-ant-..."
telegram_token: "123:abc..."
discord_token: "..."
```

Quick start (4 steps per sipeed README):
1. `picoclaw onboard` — generates config template
2. Add API key to `~/.picoclaw/config.json`
3. Add platform token(s)
4. `picoclaw gateway` — starts the server

Test: `picoclaw agent -m "What is 2+2?"` (CLI mode, no messaging platform needed)

Time-to-first-response on $10 hardware: under 1 second startup, responds within seconds of a Telegram message.

No pairing codes (unlike OpenClaw's Telegram pairing flow). Token in config = live bot.

---

## 6. ClaudeClaw — The Claude Code Companion

There are **two distinct ClaudeClaw projects**:

### A. earlyaidopters/claudeclaw (primary — Telegram bridge)
- Bridges Claude Code CLI to Telegram (and Discord)
- "Spawns the actual `claude` CLI on your machine and pipes the result back to Telegram"
- TypeScript, Node.js 20+, 521 GitHub stars, 272 commits, 7 contributors
- Local-only: runs on your machine, no cloud relay
- Wraps `@anthropic-ai/claude-agent-sdk` with `permissionMode: 'bypassPermissions'`
- Session persistence via SQLite per Telegram chat ID
- Voice pipeline: Telegram → .oga download → rename .ogg → Groq Whisper → Claude → ElevenLabs TTS → voice reply
- Memory: dual-sector SQLite (semantic + episodic) with FTS5 and salience decay
- Scheduler: cron-based with SQLite task persistence
- WhatsApp bridge: separate `wa-daemon` process via `whatsapp-web.js` (Puppeteer)

Source: https://github.com/earlyaidopters/claudeclaw

### B. moazbuilds/claudeclaw (plugin version)
- Installed as a Claude Code plugin: `claude plugin marketplace add moazbuilds/claudeclaw`
- Activated in-session: `/claudeclaw:start`
- Telegram + Discord + web dashboard
- Setup wizard for model, heartbeat, credentials, security tier
- 4 security tiers from read-only to full system access
- TypeScript, 97.5% TS codebase

Source: https://github.com/moazbuilds/claudeclaw

### The claudeclaw.md in this repo
`/home/rodrigo/dev/maestro/claudeclaw.md` is a **900-line rebuild mega-prompt** that:
- Is pasted into a fresh Claude Code session to generate a new ClaudeClaw from scratch
- Covers the full architecture spec, all file contents, all gotchas
- This is effectively the "source of truth" for what ClaudeClaw is — a build recipe, not source code itself

Key architecture from the mega-prompt:
```
Telegram/Discord/iMessage
     ↓
Media handler (voice/photo/doc/video)
     ↓
Memory context builder (inject relevant past facts)
     ↓
Claude Code SDK (spawns `claude` CLI subprocess)  ← sessions in SQLite per chat
     ↓
Response formatter + sender
     ↓
Optional TTS before sending
```

---

## 7. NanoClaw — Container-Isolated Alternative

Source: https://github.com/qwibitai/nanoclaw

NanoClaw takes a security-first approach instead of a lightweight approach:

- Each agent runs in its own Linux container (Docker / Apple Container)
- "OS-level isolation rather than permission checks"
- Filesystem: only explicitly mounted paths are visible to the agent
- No `config.yaml` — customization via direct code modification guided by Claude
- Channels added as Claude Code skills (`/add-whatsapp`, `/add-signal`)
- Per-group `CLAUDE.md` files for isolated context memory
- Setup: `gh repo fork qwibitai/nanoclaw --clone && cd nanoclaw && claude && /setup`

Architecture:
```
Channels → SQLite → Polling loop → Container (Claude Agent SDK) → Response
```

Relevant for Maestro: the per-group CLAUDE.md isolation pattern is interesting for multi-agent contexts.

---

## 8. learn-claude-code — Bash Agent Harness Reference

Source: https://github.com/shareAI-lab/learn-claude-code

This is the most directly relevant for a bash-based companion daemon. Key finding:

The minimal agent loop is:
```python
while True:
    response = client.messages.create(model=MODEL, messages=messages, tools=TOOLS)
    messages.append({"role": "assistant", "content": response.content})
    if response.stop_reason != "tool_use":
        return
    # Execute tools, append results, loop continues
```

This loop is **unchanged across all 12 sessions** — only the harness around it evolves. This is the core insight for bash implementations: the loop itself is trivial; all complexity lives in the harness.

Progressive harness layers (12 sessions):
1. s01-s02: Tool dispatch, single execution
2. s03-s06: Task planning, skill loading, context compression
3. s07-s08: Task graphs, background execution
4. s09-s12: Multi-agent coordination, isolation, autonomous claiming

Related project mentioned: **claw0** — always-on personal assistant with heartbeat, cron, and multi-channel messaging (appears to be a precursor or sibling to ClaudeClaw).

---

## 9. Competitor Matrix

| Project | Language | RAM | Start | Channels | Memory | Daemon | Install |
|---------|----------|-----|-------|----------|--------|--------|---------|
| OpenClaw | TypeScript | ~1.2 GB | ~8s | 30+ (plugins) | Workspace files | launchd/systemd | npm/brew/curl |
| PicoClaw (sipeed) | Go | <10 MB | <1s | 12+ (built-in) | config.json | systemd | single binary |
| ZeroClaw | Rust | ~4 MB | <10ms | 30+ | — | systemd | single binary |
| ClaudeClaw (earlyaidopters) | TypeScript | moderate | ~3s | Telegram/Discord/iMessage | SQLite (FTS5) | launchd/systemd/pm2 | git clone + npm |
| ClaudeClaw (moazbuilds) | TypeScript | moderate | — | Telegram/Discord | folder-based | via Claude Code plugin | claude plugin install |
| NanoClaw | TypeScript | moderate | — | WhatsApp/Telegram/Discord/Slack/Gmail | per-group CLAUDE.md | Docker containers | gh fork + claude |
| nanobot (HKUDS) | Python | low | fast | 10+ | token-based | — | onboard CLI |

---

## 10. Patterns Adoptable for a Bash-Based Companion Daemon

Ranked by direct applicability:

### 10.1 PID lock file pattern (ClaudeClaw)
```bash
PID_FILE="$STORE_DIR/daemon.pid"
acquire_lock() {
  if [ -f "$PID_FILE" ]; then
    old_pid=$(cat "$PID_FILE")
    kill -0 "$old_pid" 2>/dev/null && kill "$old_pid"
  fi
  echo $$ > "$PID_FILE"
}
release_lock() { rm -f "$PID_FILE"; }
trap release_lock EXIT INT TERM
```
Prevents duplicate daemon instances. The ClaudeClaw implementation checks liveness with `process.kill(pid, 0)` before killing — same pattern applies in bash with `kill -0`.

### 10.2 Typing indicator refresh (ClaudeClaw)
In bash, replicate with a background process sending periodic "still working" signals:
```bash
send_typing() {
  while true; do
    curl -s -X POST "$TELEGRAM_API/sendChatAction" \
      -d "chat_id=$CHAT_ID&action=typing" > /dev/null
    sleep 4
  done
}
send_typing &
TYPING_PID=$!
# ... run agent ...
kill $TYPING_PID 2>/dev/null
```
Telegram typing indicator expires at ~5s; refresh every 4s.

### 10.3 OGA → OGG rename (ClaudeClaw voice pipeline)
Groq Whisper refuses `.oga` extension but accepts `.ogg` (same format):
```bash
cp "$voice_file.oga" "$voice_file.ogg"
# send .ogg to Groq
```

### 10.4 Single binary distribution (PicoClaw)
For a bash daemon, the equivalent is: single script + `chmod +x` + optional `make install` → `/usr/local/bin/`. No package manager at runtime. Ship dependencies as bundled functions within the script.

### 10.5 bypassPermissions mode (ClaudeClaw)
When running as a daemon with no terminal, Claude Code must be invoked with permission bypass:
```bash
claude --dangerously-skip-permissions -p "$message" \
  --output-format json \
  --resume "$session_id"
```
Without this flag, Claude pauses for tool confirmations that never come — daemon hangs.

### 10.6 YAML config (PicoClaw) vs .env (ClaudeClaw)
PicoClaw uses YAML, ClaudeClaw uses `.env` files read via a safe parser (never polluting `process.env`). For bash: source the `.env` only into local variables, not `export`.

### 10.7 Systemd user service template (PicoClaw / ClaudeClaw)
```ini
[Unit]
Description=Maestro Daemon
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/maestro-daemon
Restart=on-failure
RestartSec=5
StandardOutput=append:/tmp/maestro-daemon.log
StandardError=append:/tmp/maestro-daemon-error.log

[Install]
WantedBy=default.target
```
Install at `~/.config/systemd/user/maestro-daemon.service`, then `systemctl --user enable --now maestro-daemon`.

### 10.8 Cron-based scheduler with SQLite (ClaudeClaw)
Poll every 60 seconds, check SQLite for due tasks:
```bash
while true; do
  sqlite3 "$DB" \
    "SELECT id, prompt, chat_id FROM scheduled_tasks
     WHERE status='active' AND next_run <= strftime('%s','now')" |
  while IFS='|' read -r id prompt chat_id; do
    result=$(claude -p "$prompt" --dangerously-skip-permissions)
    send_telegram "$chat_id" "$result"
    next=$(compute_next_run "$schedule")
    sqlite3 "$DB" "UPDATE scheduled_tasks SET last_run=strftime('%s','now'), next_run=$next WHERE id='$id'"
  done
  sleep 60
done
```

### 10.9 Session resumption via file (ClaudeClaw)
Per-chat session IDs persisted to SQLite. In bash, a flat file per chat is sufficient:
```bash
SESSION_FILE="$STORE_DIR/session_${chat_id}.txt"
session_id=$(cat "$SESSION_FILE" 2>/dev/null)
result=$(claude -p "$message" --dangerously-skip-permissions \
  ${session_id:+--resume "$session_id"} \
  --output-format json)
new_session=$(echo "$result" | jq -r '.session_id // empty')
[ -n "$new_session" ] && echo "$new_session" > "$SESSION_FILE"
```

### 10.10 Gateway mode separation (PicoClaw)
PicoClaw runs in `agent` mode (CLI, no server) or `gateway` mode (server, channels). For Maestro:
- Heartbeat/cron = agent mode: fire-and-forget, no persistent server
- Channel bridge = gateway mode: long-polling loop

These should be separate processes or invocable modes, not entangled.

---

## 11. Anti-Patterns Observed

**Anti-pattern: ClawHub / Plugin marketplace for channels**
OpenClaw's plugin-per-channel approach means 41.7% of community skills contain vulnerabilities. PicoClaw and ZeroClaw avoid this by building channels in-tree. For Maestro: don't externalize what can be first-party.

**Anti-pattern: Node.js runtime for a companion daemon**
~1.2 GB idle RAM for a daemon that mostly waits is wasteful. PicoClaw's Go binary (<10 MB) proves this is solvable. A bash daemon with no Node.js runtime can approach this baseline.

**Anti-pattern: Polling Telegram getUpdates in the main process**
Long-polling is blocking by nature. ClaudeClaw handles this with async Node.js; in bash it requires a background subshell for the polling loop with IPC via named pipe or SQLite.

**Anti-pattern: process.env pollution (ClaudeClaw gotcha)**
Explicitly documented in claudeclaw.md: never set `process.env` from `.env` because the Claude Code SDK subprocess inherits it, potentially leaking secrets. Bash equivalent: never `export` credentials; use local variables only.

**Anti-pattern: launchd without ThrottleInterval**
ClaudeClaw's gotcha #9: without `ThrottleInterval 5` in the launchd plist, a crash loop hammers the machine. Always set it.

---

## 12. SEO / Community Landscape

- "picoclaw" has strong search presence due to sipeed/picoclaw's 12k+ stars
- "claudeclaw" finds earlyaidopters/claudeclaw first
- "nanoclaw" finds qwibitai/nanoclaw (container-focused)
- "zeroclaw" finds zeroclaws.io (Rust, production focus)
- Medium, KDnuggets, DataCamp coverage suggests these projects have crossed into mainstream developer awareness as of March 2026
- The learn-claude-code "Bash is all you need" framing is relevant for validating a pure-bash approach

---

## Sources

- [sipeed/picoclaw — GitHub](https://github.com/sipeed/picoclaw)
- [Az0xel/picoclaw- — GitHub](https://github.com/Az0xel/picoclaw-)
- [earlyaidopters/claudeclaw — GitHub](https://github.com/earlyaidopters/claudeclaw)
- [moazbuilds/claudeclaw — GitHub](https://github.com/moazbuilds/claudeclaw)
- [qwibitai/nanoclaw — GitHub](https://github.com/qwibitai/nanoclaw)
- [HKUDS/nanobot — GitHub](https://github.com/HKUDS/nanobot)
- [shareAI-lab/learn-claude-code — GitHub](https://github.com/shareAI-lab/learn-claude-code)
- [PicoClaw Deploy Platform — picoclaw.dev](https://picoclaw.dev/)
- [Pico Claw Getting Started — pico-claw.com](https://pico-claw.com/getting-started-pico-claw.html)
- [ZeroClaw vs OpenClaw vs PicoClaw 2026 — zeroclaws.io](https://zeroclaws.io/blog/zeroclaw-vs-openclaw-vs-picoclaw-2026/)
- [Best OpenClaw Variants — Medium](https://medium.com/data-science-in-your-pocket/best-openclaw-variants-to-know-2aac9eb6bd6d)
- [Building ClaudeClaw — Medium](https://medium.com/@mcraddock/building-claudeclaw-an-openclaw-style-autonomous-agent-system-on-claude-code-fe0d7814ac2e)
- [claudeclaw.md (local, this repo)](/home/rodrigo/dev/maestro/claudeclaw.md)
