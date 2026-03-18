---
feature: "OpenClaw parity — remaining differential + plugin ports"
created: "2026-03-18"
status: roadmap
priority: medium
---

# OpenClaw Parity: Remaining Items

## Already Implemented (This Session)

| OpenClaw Feature | Maestro Equivalent | Status |
|------------------|-------------------|--------|
| Always-on loop | opus-loop-hook.sh (Stop hook) | DONE |
| Heartbeat monitoring | awareness/SKILL.md + scheduler/SKILL.md | DONE |
| Event triggers | webhooks/SKILL.md + ci-watch/SKILL.md | DONE |
| Skill registry | skill-factory/SKILL.md (auto-generation) | DONE |
| Memory system | memory/SKILL.md (semantic + episodic) | DONE |
| Multi-agent dispatch | dev-loop agents in worktrees | DONE |
| Session persistence | state.local.md + opus --resume | DONE |
| North Star anchoring | Re-injected at every phase | DONE |
| Self-improvement | retrospective/SKILL.md + learning | DONE |
| Notifications | notify/SKILL.md (Slack/Discord/Telegram) | DONE |
| Browser automation | Playwright MCP (research skill) | DONE |
| Voice interaction | voice/SKILL.md (maps to /voice) | DONE |

## Remaining Differential

### 1. SOUL.md Pattern (OpenClaw's personality file)
OpenClaw uses SOUL.md to define agent personality/behavior.
Maestro equivalent: `.maestro/dna.md` covers project context but not
agent personality. Could add a `personality` section to config or
create a `.maestro/soul.md` for custom agent behavior rules.
**Priority: LOW** (DNA + profiles already cover this)

### 2. Multi-Channel Simultaneous Connections
OpenClaw connects to 20+ platforms simultaneously.
Maestro: focused on developer workflow (terminal + Desktop).
Notifications skill covers outbound to Slack/Discord/Telegram.
**Priority: LOW** (not needed for dev orchestration)

### 3. Canvas Server (Visual Workspace)
OpenClaw has a web canvas for HTML/CSS/JS dashboards.
Maestro: visualize skill generates Mermaid diagrams + ASCII.
Claude Code Desktop renders Mermaid inline.
**Priority: LOW** (Mermaid covers 80% of the need)

## Top Community Plugins to Port

### High Priority (clear value for developers)

1. **Ruflo-style cost-aware routing**
   Already have: model routing in delegation skill
   Missing: auto-downgrade when simple task detected mid-execution
   Implementation: enhance delegation skill with complexity scoring

2. **claude-reflect confidence-scored learning**
   Already have: retrospective with friction signals
   Missing: confidence scores (0.0-1.0) on each learning
   Implementation: add confidence field to semantic memory entries

3. **Cursor Automations event triggers**
   Already have: webhooks + ci-watch
   Missing: PR comment triggers, PagerDuty integration
   Implementation: add provider files to webhooks skill

4. **SQUAD.md team definition**
   Already have: profiles + skill-factory
   Missing: standard format for defining a team of agents
   Implementation: add `.maestro/squad.md` for team definitions

### Medium Priority (nice-to-have)

5. **Tree-sitter repo mapping** (Aider)
   Already have: project-dna scans codebase
   Missing: AST-level function/class mapping for precise context
   Implementation: enhance project-dna with `tree-sitter` parsing

6. **Session replay / export** (claude-swarm)
   Already have: build-log skill
   Missing: exportable format (HTML, blog post)
   Implementation: add export modes to build-log

7. **Meta-rules** (claude-meta)
   Already have: retrospective proposes improvements
   Missing: rules that teach HOW to write rules
   Implementation: add meta-learning section to retrospective

### Low Priority (niche)

8. **tmux session management** (Claude Squad)
   Claude Code handles sessions natively — not needed.

9. **Neural Q-learning routing** (Ruflo)
   Overkill — simple heuristics work fine for model selection.

10. **WASM kernels** (Ruflo)
    Claude Code plugin = markdown only — not applicable.
