# OpenClaw Deep-Dive Research

**Date:** 2026-03-18
**Scope:** Features and patterns OpenClaw has that Maestro does not — focused on 10 specific topics
**Sources:** GitHub repository, official docs, community newsletters, release notes, issue tracker, ClawHub registry

---

## Community Scale (Verified)

OpenClaw is the most-starred software project in GitHub history as of March 2026.

| Date | Stars | Forks | Contributors | Open Issues |
|---|---|---|---|---|
| 2026-02-25 | 226,887 | 43,412 | 852 | — |
| 2026-03-03 | 250,829 | 48,274 | 1,075 | 9,574 |
| 2026-03-09 | 285,305 | 54,247 | 1,175 | 11,335 |
| 2026-03-14 | 311,575 | 59,291 | 1,243 | — |

Growth rate: ~85,000 stars in 17 days. Surpassed React, Vue, and every other software project on GitHub.

Weekly newsletter on Buttondown with archives going back to at least February 2026.
Source: https://openclaws.io/blog/openclaw-250k-stars-milestone

---

## 1. Skill Marketplace (ClawHub)

### What It Is

ClawHub is a standalone public registry at `clawhub.ai` for OpenClaw skills — reusable executable Markdown + scripts that extend agent capabilities. The registry has a separate GitHub org at `github.com/openclaw/clawhub`.

As of 2026-02-28: **13,729 community-built skills** in the registry.
Source: https://advenboost.com/en/clawhub/

### Discovery Mechanism

- **Vector search**: Uses OpenAI `text-embedding-3-small` + Convex vector index. Queries match against skill descriptions and body content. Not keyword-matching — semantic search.
- **CLI commands**: `clawhub search <query>`, `clawhub explore`
- **Web UI**: Browsable categories, "popular skills" ranked by download count, curated "highlighted" section

### Installation Flow

```bash
clawhub install <slug>          # downloads to ./skills
clawhub inspect <slug>          # examine without installing
clawhub list                    # show installed
clawhub update --all            # bulk update
clawhub uninstall <slug>        # remove local only (not from registry)
clawhub publish <path>          # publish with version tags
clawhub sync --all              # push updates to registry
```

Skills deposit into `./skills` (workspace scope) or `~/.openclaw/skills` (global scope).
Source: https://github.com/openclaw/clawhub

### Versioning

- Semantic versioning with tag support including `latest`
- Changelogs per skill version
- Users can pin to specific versions or track `latest`
- `rollback-ready` (stated on clawhub.ai)

### Trust Scoring

- **No formal trust score** — the `nonSuspicious=true` URL parameter is a filter, not a score
- Community star + comment system. Admins/mods can curate and approve skills
- ClawHub declared security metadata checking: skills must declare env vars, required binaries, and config in SKILL.md frontmatter; platform checks declarations against actual behavior
- **VirusTotal partnership** (announced March 2026): VirusTotal's Code Insight scans skills for dangerous patterns (remote code execution, obfuscation, unsafe commands) using AI analysis — not signature-based
- No publish-time scanning on the publishing workflow (criticized as absent by VirusTotal blog)

### Security Reality (Verified Breach)

The `ClawHavoc` / `clawdhub` malware campaign (February 2026) distributed 341 malicious skills designed to:
- Exfiltrate environment variables
- Inject backdoor prompts into agent sessions
- Deliver Atomic Stealer (AMOS) on macOS via obfuscated Base64 scripts

A single publisher account (`hightower6eu`) published 314 malicious skills. The attack vector: skill installation instructions directing users to run external executables or scripts, positioned as normal setup.

ClawHub's platform response to the breach is not documented in available sources.
Source: https://snyk.io/articles/clawdhub-malicious-campaign-ai-agent-skills/, https://blog.virustotal.com/2026/02/from-automation-to-infection-how.html

### SKILL.md Frontmatter Schema (Concrete Format)

```yaml
---
name: my-skill
description: what the skill does
homepage: https://example.com
user-invocable: true
disable-model-invocation: false
command-dispatch: tool
command-tool: my_tool
command-arg-mode: raw
metadata: '{"openclaw.os":"darwin","openclaw.requires.bins":["ffmpeg"],"openclaw.requires.env":["MY_API_KEY"],"openclaw.install":{"brew":"ffmpeg"},"openclaw.emoji":"🎵"}'
---
```

Metadata gates (evaluated at load time):
- `openclaw.always` — include regardless of gates
- `openclaw.os` — restrict to `darwin` / `linux` / `win32`
- `openclaw.requires.bins` — all must be present
- `openclaw.requires.anyBins` — at least one must be present
- `openclaw.requires.env` — environment variables that must be set
- `openclaw.requires.config` — paths in `openclaw.json` that must be truthy
- `openclaw.install` — auto-install spec (brew/node/go/uv/download)

Token cost: ~195 base characters + ~97 per skill when ≥1 skill present. Roughly 24 tokens per skill.
Source: https://docs.openclaw.ai/tools/skills

---

## 2. Multi-Platform Messaging Bridges

### Supported Platforms (Full List)

WhatsApp, Telegram, Slack, Discord, Google Chat, Signal, BlueBubbles (iMessage), iMessage (legacy), IRC, Microsoft Teams, Matrix, Feishu, LINE, Mattermost, Nextcloud Talk, Nostr, Synology Chat, Tlon, Twitch, Zalo, Zalo Personal, WebChat — **22 platforms**.

Also: macOS, iOS/Android nodes (treated as channel endpoints, not just apps).

### Routing Architecture

The Gateway (WebSocket on `127.0.0.1:18789`) is the single control plane. All channel adapters connect to it as plugins. Sessions are routed per-channel and per-agent via configuration mappings:

```
channels/<platform>/ → agent configuration → session policy
```

Sessions encode scope: `agent:<agentId>:main` (full capabilities), DM sessions, or group sessions with distinct tool access policies.

### Security Model

- Pairing by default for DM channels on: Telegram, WhatsApp, Signal, iMessage, Microsoft Teams, Discord, Slack
- Unknown senders receive a pairing code — approval adds them to local allowlist
- Full public access requires explicit opt-in

### Recent Channel Additions (2026)

- Slack Block Kit message support in agent replies (v2026.3 line)
- Feishu: structured approval cards, quick-action launcher cards, reasoning stream with markdown blockquotes, identity-aware card headers/note footers
- Telegram: partial streaming mode by default, `sendMessageDraft` for private preview streaming, image/GIF document-upload via `--force-document`

---

## 3. Live Canvas

### What It Is

Canvas is an agent-driven visual workspace — a persistent HTML surface agents can push content to. Not a multi-user collaboration feature. It is agent-to-user rendering, not user-to-user.

The name "Live Canvas" appears in third-party articles; official docs call it "Canvas."

### How Agents Control It

Agents issue CLI commands through the Gateway WebSocket:
- `canvas present` — show the panel
- `canvas navigate --url "/"` — route to path, HTTP(S), or `file://`
- `canvas eval --js "<script>"` — execute JavaScript inside the rendered context
- `canvas snapshot` — capture image of current state

HTTP alternative: `POST` to `/push` (loopback-only endpoint). WebSocket clients receive updates in real time.

### A2UI Framework (v0.8)

A2UI is OpenClaw's server-to-client component framework. Events pushed to canvas:
- `beginRendering(rootComponentId)` — initiate rendering
- `surfaceUpdate(componentTree)` — push Column/Text/etc. component structures
- `dataModelUpdate(delta)` — modify underlying data state
- `deleteSurface(surfaceId)` — remove a rendered surface

Default A2UI host: `http://<gateway-host>:18789/__openclaw__/a2ui/`

### Deep Linking Back to Agent

Canvas can trigger new agent runs via: `window.location.href = "openclaw://agent?message=..."`. This creates bidirectional agent↔UI interaction. Confirmations prompt unless a valid key is supplied.

### Platform Implementations

| Platform | Renderer |
|---|---|
| macOS | Native `WKWebView` |
| iOS | Swift UI component wrapping `WKWebView` |
| Android | `WebView` |
| Browser | Tab with standard web rendering |

### Storage

Files stored at `~/Library/Application Support/OpenClaw/canvas/<session>/`, served via custom `openclaw-canvas://` URL scheme. Blocks directory traversal via custom scheme restrictions.
Source: https://docs.openclaw.ai/platforms/mac/canvas, https://www.tencentcloud.com/techpedia/141077

---

## 4. Companion Apps (macOS / iOS / Android)

### Architecture Model

Apps are **nodes** that pair to the Gateway via WebSocket. They are not standalone apps — they extend the Gateway with platform-specific capabilities. The Gateway can run without any companion app.

### macOS App

- Menu bar control: Gateway start/stop, health status indicator
- Voice Wake: trigger phrase detection (Porcupine engine) → activation chime → push-to-talk overlay
- Canvas: rendered via native WKWebView
- Exposes to agents: `system.run`, Camera, Screen Recording, macOS-only CLI tools
- Remote Gateway SSH control (can control a remote Linux gateway from the Mac app)
- Debug tools

### iOS App (Node)

Connects via device pairing (QR code via `/pair qr`).
- Tabs: Connect / Chat / Voice
- Canvas surface (Swift UI wrapped WKWebView)
- Camera access
- Screen capture
- Voice trigger forwarding to Gateway
- First-run welcome pager (added v2026.3.13)

### Android App (Node)

Connects via device pairing.
- Tabs: Connect / Chat / Voice
- Canvas surface (WebView)
- Camera access
- Screen capture
- **Continuous voice mode** (unlike iOS which has wake-word-only)
- Device command families exposed to agents:
  - Notifications
  - Location
  - SMS
  - Photos
  - Contacts
  - Calendar
  - Motion detection
  - Call log search (added recent changelog)
- App size: ~7MB (after 2026.3.13 reduction)

Source: https://docs.openclaw.ai/platforms/macos, https://vpn07.com/en/blog/2026-openclaw-companion-app-macos-menubar-guide.html

---

## 5. Voice Wake Words

### macOS/iOS Implementation

- Engine: **Porcupine** (by Picovoice) for wake word detection
- Configuration file: `wake.yaml`
- Default trigger: `"hey claw"`
- Sensitivity: 0.0 (strict) to 1.0 (lenient)

```yaml
wake:
  enabled: true
  engine: porcupine
  keyword: "hey claw"
  sensitivity: 0.5
```

Flow: wake word detected → activation chime → begin recording → silence timeout → send to STT → send to agent.

### STT Pipeline

Providers (configurable):
- **Cloud**: OpenAI Whisper API, Groq, Deepgram, Google Gemini, Mistral Voxtral
- **Local CLI**: `whisper-cli`, `whisper` (Python), `sherpa-onnx-offline`

Config options: `maxBytes` (default 20MB), `maxChars` (transcript trim), `timeoutSeconds` (default 60s), `echoTranscript`, group-chat mention detection before processing.

### TTS Pipeline

- **ElevenLabs** (primary): configurable `voice_id`, model `eleven_turbo_v2_5` (faster/cheaper) or `eleven_monolingual_v1`
- **System TTS** (fallback)
- Cost warning: $50–100+/month at heavy voice usage with ElevenLabs

### Android Status

Wake word detection on Android is **deliberately disabled** in `NodeRuntime.kt` (line 143: `voiceWakeMode = { VoiceWakeMode.Off }`). Android uses continuous voice mode instead. Community issue #30447 requests enabling wake word on Android with Vosk or local Whisper as on-device STT. No official timeline given.

Source: https://www.meta-intelligence.tech/en/insight-openclaw-voice, https://github.com/openclaw/openclaw/issues/30447

---

## 6. Local Model Support (Ollama)

### Integration Architecture (as of v2026.3.12)

Ollama, vLLM, and SGLang were moved from core to **provider-plugin architecture** in v2026.3.12 (March 13, 2026). Each is now a bundled plugin with provider-owned:
- Onboarding flow
- Discovery (local endpoint detection)
- Model picker registration
- Post-selection hooks

### Ollama Specifics

- Auto-detected at `http://127.0.0.1:11434` when `OLLAMA_API_KEY` is set (opt-in)
- Plugin adds Ollama to the onboarding wizard and model selection UI
- Supports streaming and tool calling (native Ollama API)
- Known bug: local Ollama models hang/timeout in v2026.3.8 (issue #41871); remote ollama.com models work; fixed status unclear

### vLLM and SGLang

- vLLM: default `http://127.0.0.1:8000/v1`, `VLLM_API_KEY` optional, OpenAI-compatible
- SGLang: default `http://127.0.0.1:30000/v1`, `SGLANG_API_KEY` optional, OpenAI-compatible

### Key Rotation / Failover

Providers support key rotation on rate-limit (429) responses only. Key resolution precedence:
1. `OPENCLAW_LIVE_<PROVIDER>_KEY` (single override)
2. `<PROVIDER>_API_KEYS` (comma/semicolon list)
3. `<PROVIDER>_API_KEY`
4. `<PROVIDER>_API_KEY_*` (numbered variants)

Non-rate-limit failures terminate immediately — no rotation.

### Custom Provider Config

```json
{
  "models": {
    "providers": {
      "my-local": {
        "baseUrl": "http://localhost:8080/v1",
        "apiKey": "${MY_LOCAL_KEY}",
        "api": "openai-completions",
        "models": [{ "id": "llama3.3", "name": "Llama 3.3" }]
      }
    }
  }
}
```

Source: https://docs.openclaw.ai/concepts/model-providers, https://blockchain.news/ainews/openclaw-v2026-3-12-release-dashboard-v2-fast-mode-plugin-architecture-for-ollama-sglang-vllm-and-ephemeral-device-tokens

---

## 7. Gateway Daemon Architecture

### Process Model

Gateway binds to `127.0.0.1:18789` — loopback-only by design. It runs as:
- **macOS**: launchd user service (installed via `openclaw onboard --install-daemon`)
- **Linux**: systemd user service
- **Windows**: Windows service (with compatibility tweaks in v2026.3.13)

The macOS app manages the daemon; on Linux, systemd controls lifecycle.

### WebSocket Control Plane

- Protocol: typed WebSocket frames validated against JSON Schema (generated from TypeBox definitions)
- Idempotency keys required on all side-effecting operations (prevents duplicate actions on retry)
- Event subscriptions: `agent`, `presence`, `health`, `tick`
- All channel adapters, CLI tools, web UI, and mobile nodes connect through this single plane

### Tailscale Integration

Gateway can be exposed remotely via:
- **Tailscale Serve** (tailnet-only access)
- **Tailscale Funnel** (public access)
while remaining localhost-bound for local connections. Auto-configures on detection.

### Remote Access from macOS App

macOS app can control a remote Linux Gateway via SSH — the macOS node's local capabilities (Canvas, Voice Wake, Screen Recording) become available to a headless Linux server.

### Kubernetes Support

Starter Kubernetes install docs added in v2026.3.12.

Source: https://ppaolo.substack.com/p/openclaw-system-architecture-overview, https://medium.com/@rogerio.a.r/setting-up-a-private-local-llm-with-ollama-for-use-with-openclaw-a-tale-of-silent-failures-01cadfee717f

---

## 8. Plugin/Skill Hot-Reloading

### Skills Hot-Reloading

Skills watcher is **enabled by default** and monitors SKILL.md files:

```json
{
  "skills": {
    "load": {
      "watch": true,
      "watchDebounceMs": 250
    }
  }
}
```

**Critical behavior**: "OpenClaw snapshots the eligible skills when a session starts and reuses that list for subsequent turns." Changes to SKILL.md files refresh snapshots, but **only take effect on new sessions** — not mid-session. The watcher triggers snapshot refresh on file change.

### Plugin (Extension) Hot-Reloading

Development mode: `pnpm gateway:watch` — auto-reloads gateway on source/config changes during development. This is the dev workflow, not production.

Production plugins follow a scan-and-load pattern: Gateway scans workspace packages for an `openclaw.extensions` field in `package.json`. No live production hot-swap documented — new plugins require gateway restart.

### Three-Tier Skill Precedence

1. Workspace skills (`<workspace>/skills`) — highest priority
2. Managed/local skills (`~/.openclaw/skills`)
3. Bundled skills — lowest priority
4. Extra directories via `skills.load.extraDirs`

This means workspace skills shadow bundled ones, enabling local overrides without modifying core.

Source: https://docs.openclaw.ai/tools/skills, https://ppaolo.substack.com/p/openclaw-system-architecture-overview

---

## 9. New Features Since Last Research (March 2026)

These are features added or significantly modified in the v2026.3.x line, which represents the most recent development:

### v2026.3.13 (March 14)

- Chrome DevTools MCP attach mode — agents connect to live signed-in Chrome sessions via remote debugging
- Browser batched actions and selector targeting
- Android chat settings redesign with grouped device/media sections
- iOS first-run welcome pager
- Docker `OPENCLAW_TZ` timezone override
- Cron job binding to current or named sessions
- Windows gateway stability fixes

### v2026.3.12 (March 13) — Major Release

- Dashboard v2: modular views, command palette, mobile bottom tabs
- OpenAI GPT-5.4 fast mode with session-level toggles
- Anthropic Claude fast mode (API-level service tier mapping)
- Ollama, vLLM, SGLang moved to provider-plugin architecture
- Google Vertex Gemini flash-lite normalization
- Subagent `sessions_yield` for immediate turn completion
- Cross-agent subagent workspace resolution
- Device pairing bootstrap token (ephemeral)
- WebSocket browser origin validation enforcement
- Implicit workspace plugin auto-load disabled (security hardening)
- Execution approval hardening (multiple vectors)
- Kubernetes starter install docs
- MiniMax-M2.5-highspeed added to provider catalog

### v2026.3.11 (March 12)

- Session persistence improvements
- Additional security hardening

### v2026.3.2 (Earlier March)

- SecretRef support across 64 credential targets
- First-class `pdf` tool (native Anthropic + Google, fallback for others)
- Shared `sendPayload` across Discord, Slack, WhatsApp for multi-media
- Audio file transcription in runtime API for extensions
- File attachments for `sessions_spawn` (base64/utf8 encoding)
- `openclaw config validate` with JSON output and detailed invalid-key paths
- `channelRuntime` exposed on `ChannelGatewayContext` in Plugin SDK
- `sessionKey` in session lifecycle hooks
- `message:transcribed` and `message:preprocessed` hook events

### Unreleased (In Development as of 2026-03-18)

- `/btw` side-question command: quick tool-less answers without changing session context
- Pluggable sandbox backends: OpenShell, mirror, and remote modes
- Firecrawl integration as onboard search provider with explicit tools
- Codex, Claude, and Cursor bundle discovery/install support
- OpenRouter, GitHub Copilot, OpenAI Codex moved to bundled plugins
- Structured approval and quick-action launcher cards for Feishu
- Owner-gated `/plugins` and `/plugin` chat commands
- Claude marketplace registry resolution with `plugin@marketplace` installs
- Android call log search capability
- Memory multimodal indexing: opt-in image and audio indexing + Gemini embeddings
- MiniMax provider consolidation

---

## 10. Most Requested Features (Community Issues)

Based on GitHub issues sorted by reactions and community newsletters:

| Feature | Issue | Reactions | Status |
|---|---|---|---|
| i18n / Localization | #3460 | 103 | Open |
| Linux/Windows native desktop apps | #75 | 42 | Open |
| Android voice wake word | #30447 | Unknown | Open, no timeline |
| DingTalk channel | #26534 | High | Open |
| Native Ollama API (streaming + tool calling) | #11828 | High | In progress |
| DeepSeek provider | Various | High | Partially implemented |
| Role-based access control | Various | High | Open |
| Persistent memory system improvements | Various | High | Active development |
| Windows-native gateway (no WSL2) | Various | High | Active in 2026.3.13 line |

The community newsletter (2026-03-09) highlights these as ongoing themes: setup friction reduction, memory multimodal expansion, and browser automation reliability.

---

## Technical Patterns Worth Noting

### Pattern 1: Gateway-as-Control-Plane

All intelligence about routing, auth, session state, and tool dispatch lives in one loopback WebSocket server. Every client (CLI, web UI, mobile app, channel adapter) is a dumb terminal against this plane. Enables centralized security enforcement and single audit trail.

### Pattern 2: Skills-as-Markdown

Skills are Markdown files with YAML frontmatter + embedded scripts. The LLM reads the Markdown body as tool documentation; scripts execute when the LLM invokes the skill. No code generation required — skills are authored in natural language with executable sections. Token cost is calculable and deterministic.

### Pattern 3: Declarative Dependency Gating

Skills declare their OS, required binaries, and required env vars in frontmatter. The runtime gates skill availability at load time — if `ffmpeg` isn't installed, the skill simply doesn't appear in the model's context. No runtime errors; graceful degradation.

### Pattern 4: Provider-Plugin Architecture

LLM providers (including local ones like Ollama) are first-class plugins — not hardcoded in core. Each provider plugin owns its onboarding flow, model catalog registration, auth handling, and request normalization. The core only sees a normalized provider interface.

### Pattern 5: Ephemeral Token Bootstrap for Pairing

Device pairing uses ephemeral bootstrap tokens (added v2026.3.12). The token is short-lived, single-use, and scoped — preventing replay attacks during device onboarding.

### Pattern 6: Semantic Skill Discovery

ClawHub uses vector embeddings for skill search, not keyword matching. This enables natural-language skill discovery: "tool that resizes images" finds image processing skills without exact keyword overlap.

---

## Anti-Patterns Observed

### Anti-Pattern 1: Unvetted Skill Execution

Skills run with full host system access in main sessions. The platform's response to the ClawHavoc malware campaign (341 malicious skills, AMOS delivery) was reactive (VirusTotal partnership) rather than preventive (no publish-time scanning). The security model transfers responsibility to users ("treat third-party skills as untrusted code").

### Anti-Pattern 2: Session Snapshot Stale Skills

Skills snapshotted at session start cannot be updated mid-session. Long-running agent sessions with changing skill availability require explicit session restart, which interrupts context continuity.

### Anti-Pattern 3: Android Wake Word Disabled Without Replacement

Wake word detection on Android is intentionally disabled with no documented timeline for enabling it or shipping an alternative (on-device STT). Users on Android get continuous voice mode, which is always-on — a different UX with different battery/privacy trade-offs.

### Anti-Pattern 4: Ollama Hang Bug Not Fixed Across Minor Versions

Local Ollama models hang in v2026.3.8 (issue #41871). The issue was opened as a retest of a previously "fixed" issue (#31399), indicating regression. Remote Ollama API works; local does not. Direct Ollama API works; OpenClaw session does not. The bug vector is in OpenClaw's session timeout handling, not Ollama itself.

### Anti-Pattern 5: Security Debt on ClawHub

No publish-time scanning, no formal trust score metric, no maintainer identity verification, no code signing for skills. The `nonSuspicious` filter is a community-moderation flag, not a technical check. The VirusTotal partnership scans after publication, not before.

---

## SEO and Public Presence

- Official docs: `docs.openclaw.ai` (skills, providers, platforms well-documented)
- Marketing site: `openclaw.ai`
- Skill registry: `clawhub.ai` (also `claw-hub.net` as alternate)
- Weekly newsletter: `buttondown.com/openclaw-newsletter`
- Blog: `openclaws.io/blog`
- DigitalOcean published two explainer articles (developer audience capture)
- Ollama official docs have an OpenClaw integration page at `docs.ollama.com/integrations/openclaw`

---

## Concrete Features Maestro Should Adopt

Ordered by implementation specificity (most actionable first):

**1. Declarative skill/plugin dependency gating**
Implement frontmatter-based gates on skills: required OS, required binaries (`requires.bins`), required env vars. Skip loading the skill if gates fail. Currently Maestro has no mechanism to prevent a skill from loading when its dependencies are absent. This prevents runtime errors and keeps the model's context clean.

**2. Three-tier skill precedence with workspace override**
Workspace skills shadow global/bundled skills with the same name. Enables per-project skill customization without forking core. Currently Maestro likely has a flat skill resolution model.

**3. Skills-as-Markdown with calculable token cost**
If Maestro's skills/tools inject arbitrary amounts of text into system prompts, adopt a token-budget model per tool. OpenClaw's 24-token-per-skill estimate allows pre-flight context budget enforcement.

**4. SKILL.md watcher with session-scoped snapshot**
File system watcher (250ms debounce) that refreshes the skill snapshot. Skill changes take effect on the next new session. Maestro currently has no documented hot-reload equivalent.

**5. Provider-plugin architecture for LLM backends**
Local providers (Ollama, vLLM, custom OpenAI-compatible) should be plugins, not hardcoded. Each plugin owns its own onboarding, model catalog, and auth flow. The core sees only a normalized interface.

**6. Key rotation on rate-limit with multi-key env vars**
`PROVIDER_API_KEYS` (comma-separated) with rotation only on 429. Non-rate-limit failures terminate immediately. Four-level key resolution precedence.

**7. Vector-based skill/plugin discovery**
If Maestro develops a skill registry, semantic vector search (embedding-based) will outperform keyword search at the scale OpenClaw has reached (13,729+ skills). ClawHub uses OpenAI `text-embedding-3-small` + Convex vector index.

**8. Idempotency keys on all side-effecting Gateway operations**
OpenClaw requires idempotency keys on the WebSocket control plane for all mutations. This prevents duplicate tool invocations on retry/reconnect — critical for destructive operations.

**9. Ephemeral bootstrap tokens for device/node pairing**
Short-lived, single-use, scoped tokens for pairing new nodes to the Gateway. Prevents replay attacks during onboarding. OpenClaw added this in v2026.3.12.

**10. `/btw` side-question pattern**
A command that answers a quick question without affecting session state or tool access. Implementation: route to model with no tools, no session write-back, immediate return. Useful for in-flight clarifications during long agent runs.

**11. `sessions_yield` for immediate subagent turn completion**
When spawning subagents, `sessions_yield` allows the parent to complete its turn immediately rather than waiting for the subagent to finish. Enables true async multi-agent parallelism.

**12. Publish-time security scanning for any skill/plugin registry**
OpenClaw's ClawHub does NOT have this — it is their biggest security gap. If Maestro builds a skill registry, scanning at publish time (not just post-publish) is a concrete differentiator.

---

*Sources consulted:*
- https://github.com/openclaw/openclaw
- https://github.com/openclaw/clawhub
- https://docs.openclaw.ai/tools/skills
- https://docs.openclaw.ai/platforms/mac/canvas
- https://docs.openclaw.ai/concepts/model-providers
- https://docs.openclaw.ai/nodes/audio
- https://github.com/openclaw/openclaw/releases/
- https://github.com/openclaw/openclaw/blob/main/CHANGELOG.md
- https://github.com/openclaw/openclaw/issues/30447
- https://clawhub.ai/
- https://openclaw.ai/
- https://ppaolo.substack.com/p/openclaw-system-architecture-overview
- https://blog.virustotal.com/2026/02/from-automation-to-infection-how.html
- https://snyk.io/articles/clawdhub-malicious-campaign-ai-agent-skills/
- https://openclaws.io/blog/openclaw-250k-stars-milestone
- https://blockchain.news/ainews/openclaw-v2026-3-12-release-dashboard-v2-fast-mode-plugin-architecture-for-ollama-sglang-vllm-and-ephemeral-device-tokens
- https://nerdschalk.com/openclaw-2026-3-13-brings-browser-automation-upgrades-and-mobile-ui-refresh/
- https://www.meta-intelligence.tech/en/insight-openclaw-voice
- https://advenboost.com/en/clawhub/
