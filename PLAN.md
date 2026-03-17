# Maestro v2: Full-Stack Autonomous Development & Strategy Orchestrator

## Revised Plan — Fixes, Compatibility, Killer Features

> **Status:** Plan v3 — critical fixes + plugin compatibility + community research + Claude Code features deep dive
> **Date:** 2026-03-16
> **Research:** 20+ community projects analyzed, 17 installed plugins reverse-engineered, 24 Claude Code hook events mapped

---

## What Changed From v1

### Critical Fixes Applied

| Issue | v1 Problem | v2 Fix |
|-------|-----------|--------|
| **Worktree model** | Manual `git worktree add` + custom paths | Use superpowers `using-git-worktrees` pattern for feature isolation; `isolation: "worktree"` for subagent sandboxing |
| **Custom models** | Per-agent `ANTHROPIC_BASE_URL` env var switching | Removed. `model: sonnet\|opus\|haiku` on Agent tool calls. External models via gateway = Phase 5 |
| **Story dependencies** | Unhandled — stories assumed independent | `depends_on` field. Sequential by default. Parallel only for truly independent stories |
| **Error recovery** | Underspecified max-rejection behavior | Clear escalation: QA 5x → PAUSE + user guidance. Self-heal 3x → PAUSE + manual fix. ABORT → revert + cleanup |
| **Phase 1 scope** | 28 files — too big for MVP | 18 files. Cut `maestro-custom-model`, merged status commands, deferred `maestro-doctor` |
| **Plugin conflicts** | Could clash with superpowers hooks/worktrees | Explicit compatibility layer. Different state file paths. Complementary, not competing |
| **Stop hook** | Overengineered — checking modes, phases, etc. | Simplified: read state, check session, check mode, block or allow. Same pattern as Ralph Loop |
| **Hook enforcement** | Documentation-only skill rules | Hook-enforced delegation (DevSquad lesson: after 25+ sessions, Claude ignores docs; hooks physically intercept) |
| **Token efficiency** | Skills fully loaded into context | Atomic/progressive loading — only load what's needed (self-evolving-agent: 92% token reduction) |
| **Goal drift** | No anchoring for long runs | North Star anchoring — re-inject feature goal at each phase to prevent drift (self-evolving-agent pattern) |

### New: Plugin Compatibility Matrix

| Plugin | Relationship | How Maestro Uses It |
|--------|-------------|-------------------|
| **superpowers** | EXTENDS | Uses same subagent patterns, worktree conventions, implementer status protocol. Maestro adds Strategy + Research + Token tracking layers on top |
| **ralph-loop** | COEXISTS | Different state files (`.maestro/state.local.md` vs `.claude/ralph-loop.local.md`). Stop hooks check their own state only. User can use Ralph for non-Maestro loops |
| **skill-creator** | USES | Skill Factory delegates to skill-creator for creating/validating project specialists |
| **feature-dev** | DISPATCHES | `feature-dev:code-explorer` for architecture phase, `feature-dev:code-architect` for design |
| **pr-review-toolkit** | DISPATCHES | `pr-review-toolkit:review-pr` in ship phase, `pr-review-toolkit:code-reviewer` in QA |
| **commit-commands** | COMPATIBLE | Maestro's git-craft extends commit patterns. User can use either |
| **playwright** | USES MCP | Preview and research skills use Playwright MCP tools |

### New: Killer Features (Community-Inspired)

| Feature | Inspiration | What It Does |
|---------|------------|-------------|
| **Maestro Forecast** | Token anxiety in community | Estimates token cost BEFORE starting. "This feature: ~$3.20 (4 stories, 70% Sonnet)" |
| **Maestro Watch** | OpenClaw's always-on + Cursor Automations + CronCreate | Scheduled monitoring: tests, Lighthouse, regressions. Auto-creates stories. Event-driven |
| **Project DNA** | Aider's tree-sitter+PageRank repo-map + Cursor indexing | Auto-discovers tech stack, patterns, architecture. Relevance-ranked context injection |
| **Delegation Protocol** | xquads + superpowers + DevSquad hook-enforcement | Hook-enforced context injection. Each agent gets exactly what it needs |
| **Progressive Trust** | claude-coach + Ruflo cost-aware routing | Tracks reliability. Auto-suggests autonomy. Routes to cheapest capable model |
| **Self-Learning Loop** | claude-coach (6 signals) + claude-reflect + claude-meta | Detect friction → classify → propose improvement → approve. Meta-rules teach how to write rules |
| **Quality Gate** | claude-swarm's Opus quality gate | After ALL stories, Opus reviews combined output for integration + security issues |
| **Session Replay** | claude-swarm recording + build-in-public | Full build log → exportable blog. Decision audit trail. Token breakdown |
| **North Star Anchoring** | self-evolving-agent | Re-inject feature goal at each phase. Prevent drift in long autonomous runs |
| **Atomic Loading** | self-evolving-agent (92% token reduction) | Skills loaded on-demand, not all at once. Massive token savings |
| **Smart Merge** | claude-swarm dependency graph | DAG-based story ordering. Sequential share branch. Independent get parallel worktrees |
| **Event Triggers** | Cursor Automations (PR/Slack/PagerDuty) | Future: Maestro reacts to GitHub events, not just user prompts |
| **Persistent Agent Memory** | Claude Code native feature | Implementer and QA agents LEARN across sessions via `memory: project` |

---

## Community Research: What We Learned From 20+ Projects

**Analyzed:** OpenClaw (302k stars), PicoClaw, claude-coach, claude-reflect, claude-meta, self-evolving-agent, Ruflo (v3.5, 5.8K commits), wshobson/agents (112 agents, 72 plugins), claude-swarm, Claude Squad, DevSquad, Overstory, Agents Squads (SQUAD.md), AIOX-core, NanoClaw, Aider, Cursor, Windsurf, Amp

### Top 15 Patterns to Adopt

| # | Pattern | Source | Adoption |
|---|---------|--------|----------|
| 1 | **Hook-enforced delegation > docs** | DevSquad (25+ failed sessions) | Hooks enforce delegation, not just instructions |
| 2 | **6 friction signal types** | claude-coach | COMMAND_FAILURE, USER_CORRECTION, SKILL_SUPPLEMENT, VERSION_ISSUE, REPETITION, TONE_ESCALATION |
| 3 | **Cost-aware model routing** | Ruflo, DevSquad | Route to cheapest model per task. Track savings |
| 4 | **92% token reduction** | self-evolving-agent | Atomic loading: only load what's needed |
| 5 | **Dependency graph decomposition** | claude-swarm | Stories as DAG. Parallelize independent. Serialize dependent |
| 6 | **Opus Quality Gate** | claude-swarm | After all stories: Opus reviews combined output |
| 7 | **Session replay** | claude-swarm | Record every execution. Export as blog post |
| 8 | **North Star anchoring** | self-evolving-agent | Re-inject goal at each phase to prevent drift |
| 9 | **PDCA execution loop** | self-evolving-agent | Plan-Do-Check-Act. Failures become learning |
| 10 | **Meta-rules** | claude-meta | Rules that teach HOW to write rules |
| 11 | **Confidence-scored learning** | claude-reflect | Capture corrections with 0.60-0.95 confidence |
| 12 | **Pluggable adapters** | Overstory | Future: swap between Claude Code, Gemini CLI |
| 13 | **SQUAD.md compatibility** | Agents Squads | Markdown-first team definition standard |
| 14 | **Single-purpose plugins** | wshobson/agents | Each loads only its context = low token overhead |
| 15 | **Tree-sitter repo mapping** | Aider | Spend tokens on code that matters most |

### What NOT to Adopt

| Pattern | Source | Why Skip |
|---------|--------|----------|
| Neural Q-learning routing | Ruflo | Overkill. Simple heuristics suffice |
| WASM kernels in Rust | Ruflo | Plugin = markdown + bash only |
| Custom model training (LoRA) | Ruflo | Outside Claude Code capabilities |
| SQLite mail system | Overstory | Agent teams have native mailbox |
| tmux session management | Claude Squad | Claude Code handles sessions natively |
| 60+ specialized agents | Ruflo | Start with 4 agents. Grow on demand |

---

## Claude Code Technical Capabilities (For Implementation)

### 24 Hook Events

| Category | Events | Maestro Uses |
|----------|--------|-------------|
| Session | `SessionStart`, `SessionEnd` | Inject Maestro context at start |
| User Input | `Stop`, `SubagentStop` | Dev-loop continuation, QA feedback |
| Tool Execution | `PreToolUse`, `PostToolUse` | Enforce delegation, track usage |
| Team & Task | `TeammateIdle`, `TaskCompleted` | Phase 5: agent teams |
| Version Control | `WorktreeCreate`, `WorktreeRemove` | Track worktree lifecycle |

**Critical capability:** `PreToolUse` can return `updatedInput` to modify tool parameters. This enables hook-enforced delegation.

### Agent Frontmatter (Full Spec)

```yaml
---
name: implementer
description: "Dev agent with TDD discipline"
tools: [Read, Edit, Write, Bash, Grep, Glob]
model: sonnet
maxTurns: 50
skills: [tdd]
memory: project          # Persistent learning across sessions!
isolation: worktree      # Git worktree per agent
---
```

**Key:** `memory: project` enables persistent learning. Agents auto-manage MEMORY.md files. The implementer gets BETTER over time on your specific project.

### Agent Teams (Experimental — Phase 5)

- Shared task list with dependency tracking
- Direct inter-agent messaging (mailbox)
- `TeammateIdle` hook: keep teammate working
- `TaskCompleted` hook: prevent premature completion
- Each teammate: own context window, own worktree

### Plugin Capabilities

- **Can bundle MCP servers** via `.mcp.json`
- **Can define agents** in `agents/` directory
- **Can register hooks** via `hooks/hooks.json`
- **Plugin agents CANNOT use:** hooks, mcpServers, permissionMode in frontmatter (security)
- **String substitutions:** `$ARGUMENTS`, `${CLAUDE_PLUGIN_ROOT}`, `${CLAUDE_SESSION_ID}`
- **Dynamic context:** `` !`command` `` syntax runs shell at invocation time

---

## Architecture: Three Orchestration Layers

```
┌──────────────────────────────────────────────────────────────┐
│  LAYER 1: VISION & STRATEGY                                  │
│  /maestro vision    — Define/update project vision            │
│  /maestro research  — Competitive intel & benchmarking        │
│  /maestro strategy  — Marketing & growth strategy             │
│  Output: .maestro/vision.md, research.md, strategy.md         │
│  Integrates: feature-dev:code-explorer, Playwright MCP        │
└────────────────────────┬─────────────────────────────────────┘
                         │
┌────────────────────────▼─────────────────────────────────────┐
│  LAYER 2: TACTICS & ARCHITECTURE                              │
│  /maestro plan      — Decompose into epics & stories          │
│  /maestro arch      — Design/update architecture              │
│  /maestro skills    — Create specialist skills for project    │
│  /maestro forecast  — Estimate token cost before execution    │
│  Output: .maestro/architecture.md, stories/, skills/          │
│  Integrates: superpowers:writing-plans patterns, skill-creator│
└────────────────────────┬─────────────────────────────────────┘
                         │
┌────────────────────────▼─────────────────────────────────────┐
│  LAYER 3: EXECUTION                                           │
│  /maestro build     — Dev loop (implement → QA → commit)      │
│  /maestro preview   — Chrome preview of changes               │
│  /maestro ship      — Final verification + PR/deploy          │
│  /maestro watch     — Continuous monitoring (CronCreate)       │
│  Output: code, tests, commits, PRs                            │
│  Integrates: superpowers subagent patterns, ralph-loop stop   │
│              hook pattern, pr-review-toolkit, commit-commands  │
└──────────────────────────────────────────────────────────────┘
```

**`/maestro` (no subcommand)** auto-classifies and routes to the right layer.

**`/maestro opus`** enters Autonomous Mode — the mega-loop that builds entire products.

---

## MAGNUM OPUS — The Autonomous Product Builder

> *Magnum Opus* (Latin: "great work") — also a nod to Claude Opus, the model that powers Maestro's deepest reasoning.

### The Big Idea

Everything described above — research, architecture, decomposition, dev-loop, QA, shipping — is for building **one feature at a time**. Magnum Opus chains ALL of it into a **continuous product-building loop** that runs until milestones are reached or the user says stop.

**But here's what makes it unprecedented:** You can **talk to Maestro while it builds.** Add context. Change direction. Ask questions. Provide feedback. Complement the vision. All without interrupting the workers — or interrupt them if you need to.

Magnum Opus is not a black box. It's a **collaborative product builder** — an AI product team you can steer while it drives.

```
USER: /maestro opus "personal finance dashboard with budget tracking"

        │ (one-time setup — deep interview)
        ▼
  ┌─ THE DEEP INTERVIEW ─────────────────────────────────────┐
  │                                                            │
  │ Maestro asks as many questions as needed to fully          │
  │ understand the project. Adaptive — if answers are          │
  │ detailed, fewer follow-ups. If vague, drills deeper.       │
  │                                                            │
  │ 10 Dimensions explored (one question at a time):           │
  │                                                            │
  │  1. CORE PURPOSE                                           │
  │     "What problem does this solve?"                        │
  │     "Why does this need to exist?"                         │
  │                                                            │
  │  2. TARGET AUDIENCE                                        │
  │     "Who exactly will use this? B2B/B2C?"                  │
  │     "What does their day look like without this product?"  │
  │                                                            │
  │  3. SCOPE & AMBITION                                       │
  │     "Internal tool or going to market?"                    │
  │     "MVP first or full vision?"                            │
  │     "What does v1.0 look like vs the dream?"               │
  │                                                            │
  │  4. COMPETITIVE LANDSCAPE                                  │
  │     "Who else does this? What do you think of them?"       │
  │     "What would make someone choose yours?"                │
  │                                                            │
  │  5. BUSINESS MODEL                                         │
  │     "How will this make money? (or is it internal?)"       │
  │     "Free/paid/freemium? Ads? Subscriptions?"              │
  │                                                            │
  │  6. TECHNICAL CONTEXT                                      │
  │     "Existing codebase or starting fresh?"                 │
  │     "Preferred tech stack? Any constraints?"               │
  │     "Where will this be hosted/deployed?"                  │
  │                                                            │
  │  7. DESIGN & UX                                            │
  │     "Any inspirations? Sites you love the look of?"        │
  │     "Brand colors, fonts, visual identity?"                │
  │     "Mobile-first? Desktop-first? Both?"                   │
  │                                                            │
  │  8. INTEGRATIONS & DATA                                    │
  │     "What systems does it connect to?"                     │
  │     "What data sources are needed?"                        │
  │     "Any APIs or MCPs you want to use?"                    │
  │                                                            │
  │  9. SUCCESS CRITERIA                                       │
  │     "What does 'done' look like?"                          │
  │     "What KPIs matter? (users, revenue, speed?)"           │
  │     "Any hard deadlines?"                                  │
  │                                                            │
  │ 10. CONSTRAINTS & PREFERENCES                              │
  │     "Token budget? Time budget?"                           │
  │     "How autonomous do you want me to be?"                 │
  │     "Any absolute rules? Things I must/must not do?"       │
  │                                                            │
  │ The interview ADAPTS:                                      │
  │ - Short answers → follow-up questions to dig deeper        │
  │ - Detailed answers → skip related questions                │
  │ - "I don't know" → Maestro proposes options for user       │
  │ - User volunteers info → Maestro incorporates immediately  │
  │                                                            │
  │ Output: .maestro/vision.md (comprehensive product vision)  │
  │ User approves vision                                       │
  └────────────────────────┬──────────────────────────────────┘
                           │
        ┌──────────────────▼──────────────────────┐
        │        MEGA RESEARCH SPRINT              │
        │                                          │
        │  Runs 8-12 parallel research agents:     │
        │  ┌─ Market & Competitors ──────────┐    │
        │  │ Web search + Playwright          │    │
        │  │ Competitor matrix + screenshots   │    │
        │  │ Feature gap analysis              │    │
        │  └──────────────────────────────────┘    │
        │  ┌─ Tech Stack Evaluation ─────────┐    │
        │  │ Best framework for this project  │    │
        │  │ Database options + tradeoffs     │    │
        │  │ Hosting/deploy recommendations   │    │
        │  └──────────────────────────────────┘    │
        │  ┌─ SEO & Content Strategy ────────┐    │
        │  │ Keyword research                 │    │
        │  │ Content architecture             │    │
        │  │ Structured data plan             │    │
        │  └──────────────────────────────────┘    │
        │  ┌─ Monetization Analysis ─────────┐    │
        │  │ Revenue streams (ads, leads,     │    │
        │  │   affiliates, premium, SaaS)     │    │
        │  │ Pricing benchmarks               │    │
        │  └──────────────────────────────────┘    │
        │  ┌─ Architecture Design ───────────┐    │
        │  │ Data model + API design          │    │
        │  │ Component architecture            │    │
        │  │ Infrastructure map               │    │
        │  └──────────────────────────────────┘    │
        │  ┌─ Integration Map ───────────────┐    │
        │  │ MCPs needed (Supabase, Stripe..) │    │
        │  │ External APIs + data sources     │    │
        │  │ Third-party services             │    │
        │  └──────────────────────────────────┘    │
        │  ┌─ User Research ─────────────────┐    │
        │  │ Target personas                  │    │
        │  │ Jobs-to-be-done                  │    │
        │  │ User journey mapping             │    │
        │  └──────────────────────────────────┘    │
        │  ┌─ Launch Strategy ───────────────┐    │
        │  │ MVP → Growth phases              │    │
        │  │ Marketing channels               │    │
        │  │ KPI targets per phase            │    │
        │  └──────────────────────────────────┘    │
        │                                          │
        │  Output: .maestro/research/ (8+ docs)    │
        │  Synthesis: .maestro/research-brief.md   │
        └──────────────────┬──────────────────────┘
                           │
        ┌──────────────────▼──────────────────────┐
        │        ROADMAP GENERATION                │
        │                                          │
        │  From vision + research, generate:       │
        │                                          │
        │  M1: Foundation (scaffold, DB, auth)     │
        │  M2: Core Feature (main value prop)      │
        │  M3: Growth & Content (SEO, blog, guides)│
        │  M4: Monetization (premium, ads)         │
        │  M5: Polish & Launch (perf, a11y, PWA)   │
        │                                          │
        │  Each milestone has:                     │
        │  - Scope (what's included)               │
        │  - Acceptance criteria (how to verify)   │
        │  - Token budget estimate                 │
        │  - Dependencies (which milestones first) │
        │  - Research inputs (which docs inform it)│
        │                                          │
        │  Output: .maestro/roadmap.md             │
        │  User approves roadmap                   │
        └──────────────────┬──────────────────────┘
                           │
                           │
  ╔════════════════════════▼══════════════════════════════╗
  ║           AUTONOMOUS EXECUTION LOOP                   ║
  ║     (Ralph Loop-style stop hook keeps it running)     ║
  ║                                                       ║
  ║   FOR EACH MILESTONE (M1, M2, M3...):                ║
  ║   │                                                   ║
  ║   ├─ [MILESTONE START]                                ║
  ║   │   Read vision + research relevant to this M       ║
  ║   │   North Star anchor: "Building M2: Core Feature"  ║
  ║   │   Forecast: "~$8.50, 6 stories, est. 45 min"     ║
  ║   │                                                   ║
  ║   ├─ [DECOMPOSE]                                      ║
  ║   │   Break milestone into 2-8 stories                ║
  ║   │   Dependency graph between stories                ║
  ║   │   Assign model per story (cost optimization)      ║
  ║   │                                                   ║
  ║   ├─ [DEV LOOP] (per story — same as /maestro build)  ║
  ║   │   validate → delegate → implement → self-heal →   ║
  ║   │   QA review → git craft → next story              ║
  ║   │   Mode: YOLO within milestone (no per-story ask)  ║
  ║   │                                                   ║
  ║   ├─ [MILESTONE EVALUATION]                           ║
  ║   │   ├─ Run full test suite                          ║
  ║   │   ├─ TypeScript check (tsc --noEmit)              ║
  ║   │   ├─ Lighthouse audit (if UI milestone)           ║
  ║   │   ├─ Check acceptance criteria                    ║
  ║   │   ├─ Opus quality gate (combined diff review)     ║
  ║   │   │                                               ║
  ║   │   ├─ If issues found:                             ║
  ║   │   │   Auto-generate fix stories                   ║
  ║   │   │   Execute fixes (back to dev loop)            ║
  ║   │   │   Re-evaluate (max 3 fix cycles)              ║
  ║   │   │                                               ║
  ║   │   └─ If still failing after 3 cycles:             ║
  ║   │       PAUSE + show issues + ask user              ║
  ║   │                                                   ║
  ║   ├─ [MILESTONE CHECKPOINT]                           ║
  ║   │   Update: state.md, roadmap.md, token-ledger.md   ║
  ║   │   Retrospective: self-improvement cycle           ║
  ║   │   Log: .maestro/logs/M2-core-feature.md           ║
  ║   │                                                   ║
  ║   │   Mode determines what happens next:              ║
  ║   │   ├─ FULL AUTO: continue to next milestone        ║
  ║   │   ├─ MILESTONE PAUSE: show summary, ask GO/PAUSE  ║
  ║   │   └─ Token budget exceeded: PAUSE + report        ║
  ║   │                                                   ║
  ║   └─ [NEXT MILESTONE or DONE]                         ║
  ║                                                       ║
  ║   BETWEEN MILESTONES (full-auto only):                ║
  ║   ├─ Re-read vision.md (North Star)                   ║
  ║   ├─ Check: has the landscape changed?                ║
  ║   │   (new competitor? tech update? user feedback?)    ║
  ║   ├─ If yes: mini research sprint → adjust roadmap    ║
  ║   ├─ Update .maestro/state.md with progress           ║
  ║   └─ Continue to next milestone                       ║
  ║                                                       ║
  ╚═══════════════════════════════════════════════════════╝
                           │
                           ▼
  ┌────────────────────────────────────────────────────────┐
  │  ALL MILESTONES COMPLETE                                │
  │                                                        │
  │  Final quality gate (Opus reviews entire project)      │
  │  Generate: PR, changelog, build log, token summary     │
  │  Update: roadmap.md (all milestones ✓)                 │
  │  Export: build log as blog post                        │
  │                                                        │
  │  "Project complete. 5 milestones, 23 stories,          │
  │   $18.42 total, 2h 15m. Build log exported."           │
  └────────────────────────────────────────────────────────┘
```

### Magnum Opus Sub-Modes

| Mode | Flag | Behavior | Best For |
|------|------|----------|----------|
| **Full Auto** | `--full-auto` | No stops between milestones. Only pauses on failures or budget exceeded | Greenfield projects, overnight builds, high trust |
| **Milestone Pause** | `--milestone-pause` (default for auto) | Pauses between milestones for user review. Shows: summary, diff, Lighthouse, token spend | Most projects. Balance of autonomy + oversight |
| **Budget Cap** | `--budget $20` | Runs until budget reached, then pauses with progress report | Cost-conscious, experimental projects |
| **Time Cap** | `--hours 4` | Runs for N hours, then pauses | "Build while I sleep" |
| **Until Pause** | `--until-pause` | Runs indefinitely until user says `/maestro pause` | Continuous improvement, monitoring mode |

### The `/maestro opus` Command

```
/maestro opus "Build a personal finance dashboard with budget tracking"
  [--full-auto]           # No stops between milestones
  [--milestone-pause]     # Pause between milestones (default)
  [--budget $N]           # Token budget cap
  [--hours N]             # Time cap
  [--until-pause]         # Run until /maestro pause
  [--skip-research]       # Skip mega research (use existing .maestro/research/)
  [--milestones M1,M2]    # Only execute specific milestones
  [--start-from M3]       # Resume from specific milestone
```

### Mega Research Sprint (The Differentiator)

What makes Magnum Opus mode extraordinary: before writing a single line of code, Maestro does comprehensive product research. This is what a $200/hour product consultant does — but for $2-5 in tokens.

**8 Research Dimensions:**

| Dimension | Agent | Output | What It Discovers |
|-----------|-------|--------|-------------------|
| **Market & Competitors** | researcher (Playwright + WebSearch) | `research/competitors.md` | Who are the players? Feature matrices. Screenshots. Pricing. Gaps. |
| **Tech Stack** | researcher (WebSearch + code analysis) | `research/tech-stack.md` | Best framework, DB, hosting for THIS project. Tradeoffs. Benchmarks. |
| **Architecture** | feature-dev:code-architect | `research/architecture.md` | Data model, API design, component structure, infra map |
| **SEO & Content** | seo-specialist (WebSearch) | `research/seo-strategy.md` | Keywords, content architecture, structured data plan, competitor SEO |
| **Monetization** | researcher (WebSearch) | `research/monetization.md` | Revenue streams, pricing benchmarks, conversion patterns |
| **Integrations** | researcher (WebSearch + MCPs) | `research/integrations.md` | MCPs needed, external APIs, data sources, third-party services |
| **User Research** | strategist | `research/user-research.md` | Target personas, jobs-to-be-done, user journeys, pain points |
| **Launch Strategy** | strategist | `research/launch-strategy.md` | MVP scope, growth phases, marketing channels, KPI targets |

**All 8 run in parallel** (8 subagents dispatched simultaneously). Total cost: ~$3-5. Time: ~5-10 minutes.

The research output becomes the **foundation for every decision** in the autonomous loop. Each milestone references specific research docs.

### Milestone Definition Format

```markdown
---
id: M2
name: "Core Feature — Budget Dashboard"
depends_on: [M1]
estimated_stories: 6
estimated_tokens: 180000
estimated_cost: "$8.50"
research_inputs:
  - research/competitors.md (comparison patterns)
  - research/architecture.md (API design)
  - research/seo-strategy.md (structured data for comparisons)
---

## Acceptance Criteria

1. Users can view spending across all linked accounts
2. Dashboard shows spending by category with charts
3. Dashboard URL is SEO-friendly (/dashboard/monthly-overview)
4. Page has JSON-LD structured data (FinancialProduct schema)
5. Mobile-responsive dashboard layout
6. API endpoint: GET /api/v1/summary?period=month
7. Lighthouse performance > 85
8. All tests passing

## Scope

What's IN:
- Summary API endpoint
- Dashboard page component
- SEO metadata + structured data
- Mobile-responsive charts
- Unit + integration tests

What's OUT (future milestones):
- Budget alerts on overspending (M4)
- Investment portfolio tracking (M4)
- Social sharing of savings goals (M5)
```

### Auto-Generated Fix Stories

When milestone evaluation finds issues, Maestro auto-generates fix stories:

```
Milestone M2 evaluation:
  Tests:       PASS (23/23)
  TypeScript:  PASS
  Lighthouse:  WARN — LCP 2.8s (target: < 2.5s)
  Criteria:    6/8 met
    ✗ Criterion 7: Lighthouse performance > 85 (got: 78)
    ✗ Criterion 5: Mobile-responsive dashboard layout (overflow on 375px)

Auto-generating fix stories...

  Fix-M2-01: "Optimize comparison page LCP"
    - Lazy load chart components
    - Add priority hints to above-fold content
    - Estimated: ~$1.20

  Fix-M2-02: "Fix dashboard layout mobile overflow"
    - Stack charts vertically on mobile
    - Collapse secondary panels on < 640px
    - Estimated: ~$0.80

Executing fixes... (2 stories, ~$2.00)
```

### Stop Hook for Magnum Opus

The stop hook is enhanced to support the mega-loop:

```bash
# In addition to the existing dev-loop stop hook logic:

LAYER=$(echo "$FRONTMATTER" | grep '^layer:' | sed 's/layer: *//')

if [[ "$LAYER" == "opus" ]]; then
  OPUS_MODE=$(echo "$FRONTMATTER" | grep '^opus_mode:' | sed 's/opus_mode: *//')
  CURRENT_MILESTONE=$(echo "$FRONTMATTER" | grep '^current_milestone:' | sed 's/current_milestone: *//')
  TOTAL_MILESTONES=$(echo "$FRONTMATTER" | grep '^total_milestones:' | sed 's/total_milestones: *//')
  TOKEN_SPEND=$(echo "$FRONTMATTER" | grep '^token_spend:' | sed 's/token_spend: *//')
  TOKEN_BUDGET=$(echo "$FRONTMATTER" | grep '^token_budget:' | sed 's/token_budget: *//')

  # Check budget cap
  if [[ -n "$TOKEN_BUDGET" ]] && [[ "$TOKEN_SPEND" -ge "$TOKEN_BUDGET" ]]; then
    # Budget exceeded — allow exit, state will show pause reason
    exit 0
  fi

  # Check if all milestones done
  if [[ "$CURRENT_MILESTONE" -gt "$TOTAL_MILESTONES" ]]; then
    exit 0  # All done — allow exit
  fi

  # In full-auto: always block (continue to next milestone)
  # In milestone-pause: block during milestone, allow between
  case "$OPUS_MODE" in
    full_auto|until_pause)
      # Block exit — continue the loop
      ;;
    milestone_pause)
      if [[ "$PHASE" == "milestone_checkpoint" ]]; then
        exit 0  # Allow exit at milestone boundary
      fi
      ;;
  esac
fi
```

### Magnum Opus State File

Extended state file for autonomous mode:

```yaml
---
maestro_version: "1.0.0"
active: true
session_id: <uuid>
layer: opus                          # NEW: auto layer
opus_mode: milestone_pause           # full_auto | milestone_pause | budget_cap | time_cap | until_pause
feature: "Personal finance dashboard with budget tracking"
vision_approved: true
research_complete: true

# Milestone tracking
current_milestone: 2
total_milestones: 5
milestones:
  M1: { status: completed, stories: 4, tokens: 52000, cost: "$2.40" }
  M2: { status: in_progress, stories: 6, tokens: 0, cost: "$0.00" }
  M3: { status: pending }
  M4: { status: pending }
  M5: { status: pending }

# Current milestone's dev-loop state
current_story: 3
total_stories: 6
phase: implement
qa_iteration: 0
self_heal_iteration: 0
fix_cycle: 0
max_fix_cycles: 3

# Budget tracking
token_spend: 52000
token_budget: 500000               # --budget flag (0 = unlimited)
time_started: "2026-03-16T17:00:00Z"
time_budget_hours: 0               # --hours flag (0 = unlimited)

# Safety
consecutive_failures: 0
max_consecutive_failures: 5        # Pause after 5 consecutive failures

last_updated: "2026-03-16T18:30:00Z"
---
Continue Maestro auto-loop.
Milestone: M2 — Core Feature (Budget Dashboard), story 3/6.
Phase: implement.
Mode: milestone_pause (will show summary after M2 completes).
Budget: $2.40 / unlimited spent. Estimated remaining: ~$16.00.
```

### Safety Valves (Preventing Runaway)

| Safety | Trigger | Action |
|--------|---------|--------|
| **Token budget** | `token_spend >= token_budget` | PAUSE + report progress + remaining work |
| **Time budget** | `elapsed >= time_budget_hours` | PAUSE + report progress |
| **Consecutive failures** | 5+ failures in a row (QA rejects, self-heal fails) | PAUSE + show failure log + ask for help |
| **Fix cycle limit** | 3 fix cycles on same milestone evaluation | PAUSE + show unresolved issues |
| **User pause** | `/maestro pause` at any time | PAUSE + save full state for resume |
| **Context limit** | Approaching 1M token context | Self-compact, summarize, continue with fresh context |
| **Stale research** | Milestone references research > 7 days old | Mini research refresh before starting milestone |

### Context Management for Long Runs

Magnum Opus can run for hours. Context management is critical:

1. **Fresh subagent per story** — implementer gets clean context each time
2. **North Star re-injection** — vision + current milestone goal at every phase
3. **State file as memory** — all progress persisted to disk, not just in context
4. **Self-compaction** — when context approaches limit, summarize and continue
5. **Milestone boundaries as natural context resets** — between milestones, the orchestrator can start fresh with just state.md + research docs

### Resumability

Magnum Opus is fully resumable:

```
/maestro opus --resume

Resuming from state file...
  Vision: "Personal finance dashboard with budget tracking"
  Progress: M2 (story 3/6), phase: implement
  Spent: $2.40 (52K tokens)
  Time: 1h 30m elapsed

Continuing M2 story 3...
```

If the session is closed and restarted:
1. `/maestro opus --resume` reads `.maestro/state.local.md`
2. Re-loads vision.md + current milestone definition
3. Picks up at the exact story and phase where it left off
4. No lost work — everything is committed via git craft

### The "Build While I Sleep" Scenario

```
$ claude

> /maestro opus "SaaS dashboard for fleet management" --full-auto --hours 8 --budget $50

Starting autonomous build...

Vision synthesis: 3 clarifying questions
  [answers provided]

Vision approved. Running mega research sprint (8 parallel agents)...
  Research complete: 8 docs generated, $3.20 spent

Roadmap generated:
  M1: Foundation (scaffold, auth, DB) — est. $6.00
  M2: Core Dashboard (charts, categories, trends) — est. $12.00
  M3: Alerts & Notifications (real-time, email) — est. $8.00
  M4: Reports & Analytics (charts, export) — est. $10.00
  M5: Mobile & PWA (responsive, offline) — est. $8.00

  Total estimate: $47.20 (within $50 budget)

Roadmap approved. Starting autonomous execution...

  [user goes to sleep]

  M1: Foundation ████████████████████ 100% — $5.80 (4 stories, 45 min)
  M2: Fleet Dashboard ████████████░░░░░░░░ 60% — $7.20 (4/6 stories)

  ... 6 hours later ...

  M5: Mobile & PWA ██████████████████░░ 90% — $7.50 (5/6 stories)

  Budget check: $46.30 / $50.00 — continuing...

  M5: Mobile & PWA ████████████████████ 100% — $8.10

  ALL MILESTONES COMPLETE.

  Final quality gate: PASS
  Total: 5 milestones, 28 stories, $47.80, 7h 12m
  Build log: .maestro/logs/2026-03-16-fleet-dashboard.md

  [user wakes up to a working product]
```

### Why This Is OVERKILL ULTIMATE

No tool in the market does this:

| Tool | Best It Can Do | Maestro Auto |
|------|---------------|-------------|
| **Cursor** | Event-triggered single-feature automations | Build entire products from vision to launch |
| **Aider** | Pair program one feature at a time | Self-generating roadmap with milestone-driven execution |
| **Superpowers** | Execute a written plan in one session | Auto-write plans, auto-generate stories, auto-fix failures, auto-improve |
| **Ralph Loop** | Run one prompt until done | Nested loops: stories within milestones within roadmap |
| **Ruflo** | 60+ agents in a swarm | 8 parallel research agents + sequential milestone execution with self-learning |
| **OpenClaw** | Always-on chat assistant | Always-on product builder that produces shipping code |

**The key insight:** Every other tool requires the human to be the product manager. Magnum Opus IS the product manager — but one you can talk to, redirect, and collaborate with while it works.

---

## LIVE CONVERSATION CHANNEL — Talk While It Builds

### The Breakthrough

Every autonomous AI coding tool today is a black box: "give it a task, wait, get results." If you want to change direction mid-flight, you have to stop everything, adjust, restart.

Magnum Opus is different. **The orchestrator stays in the main session, responsive to you**, while background agents do the heavy lifting. You can talk to it like a colleague who's building your product right now.

### How It Works (Technical Architecture)

```
┌──────────────────────────────────────────────────────────────────┐
│  MAIN SESSION (Orchestrator)                                      │
│                                                                    │
│  ┌─ Orchestrator ──────────────────────────────────────────────┐  │
│  │                                                              │  │
│  │  Manages: state.md, roadmap, milestones, story queue         │  │
│  │  Dispatches: background agents for stories                   │  │
│  │  Listens: user messages between agent notifications          │  │
│  │  Responds: status updates, questions, confirmations          │  │
│  │                                                              │  │
│  │  WHILE agents work in background:                            │  │
│  │    → User types message                                      │  │
│  │    → Orchestrator classifies intent                          │  │
│  │    → Takes appropriate action                                │  │
│  │    → Continues orchestration                                 │  │
│  │                                                              │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                    │
│  ┌─ Background Agent 1 ─┐  ┌─ Background Agent 2 ─┐             │
│  │ Story 3: API endpoint │  │ QA Review: Story 2    │             │
│  │ (isolation: worktree) │  │ (read-only)           │             │
│  │ Status: implementing  │  │ Status: reviewing     │             │
│  └───────────┬───────────┘  └───────────┬───────────┘             │
│              │                          │                          │
│              ▼                          ▼                          │
│  ┌─ Notification ────────────────────────────────────────────┐    │
│  │ Agent 1 completed! Status: DONE. Ready for QA.            │    │
│  │ Agent 2 completed! Status: APPROVED. Commit + next story. │    │
│  └───────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────┘
```

The orchestrator uses `run_in_background: true` on Agent calls. This means:
- The orchestrator is **free to process user messages** between agent notifications
- When an agent completes, the orchestrator receives a notification and processes the result
- The user sees both their conversation AND the agent progress updates

### User Message Types

When the user types while Magnum Opus is running, the orchestrator classifies the intent:

| Intent | Example | Action | Interrupts Workers? |
|--------|---------|--------|-------------------|
| **Status check** | "What are you working on?" | Show current milestone, story, phase, token spend | No |
| **Information** | "Oh, also we need dark mode" | Save to `.maestro/notes.md`, queue for next relevant story | No |
| **Context** | "Here's the design system: [link]" | Update project DNA, inform future agents | No |
| **Complement** | "The pricing should use BRL, not USD" | Update vision.md, note for relevant stories | No |
| **Redirect** | "Skip the SEO milestone for now" | Update roadmap, mark milestone as skipped | No |
| **Reprioritize** | "Do the mobile layout before the desktop" | Reorder stories within current milestone | No |
| **Feedback** | "That chart layout looks ugly" | Create fix story, queue after current story | No |
| **Pause** | "Pause after this story" | Set phase to pause_requested | No (graceful) |
| **Urgent fix** | "STOP — there's a critical bug in auth" | Pause current work, create urgent story, execute immediately | Yes |
| **Question** | "Why did you choose Supabase?" | Explain decision from research docs | No |
| **Chat** | "How long do you think M3 will take?" | Answer from forecast + experience | No |
| **Resume** | "OK, continue" | Resume from pause point | N/A |

### The Conversation Experience

```
> /maestro opus "Build a personal finance dashboard"

Starting Magnum Opus...

Let me understand your vision. I'll ask questions one at a time.

What problem does this solve? Who needs it and why?

> People juggle 3-4 banking apps and have no idea where their money
  goes each month. I want one dashboard that shows everything clearly.

Got it — a unified view of personal finances. Is this going to market
(public SaaS) or an internal tool?

> Public SaaS. I want to compete with Mint and YNAB.

Ambitious! Freemium with premium features, or subscription-only?
What's the business model?

> Freemium — free basic dashboard, premium for AI insights,
  investment tracking, and custom reports

Great revenue model. Do you have an existing codebase or starting
from scratch?

> I have an existing Next.js project with some scrapers already

[... 5 more questions, adapting based on answers ...]

Vision synthesized. Let me show you the vision document...

[shows .maestro/vision.md summary]

Does this capture your vision? Anything to add or change?

> Yes, but also add that we want a blog for SEO content

Updated. Running mega research sprint (8 parallel agents)...

  ◐ Market research...
  ◐ Tech stack evaluation...
  ◐ SEO strategy...
  ◐ Architecture design...
  ◐ Monetization analysis...
  ◐ Integration mapping...
  ◐ User research...
  ◐ Launch strategy...

While research runs, feel free to share anything else I should know.

> Actually, here's an app I really like the design of: copilot.money

Noted! I'll have the research agent capture Copilot Money's design patterns
specifically. Saving to project notes.

  ✓ Market research complete — 12 competitors mapped
  ✓ Tech stack evaluation complete — Next.js 16 confirmed
  ✓ SEO strategy complete — 45 target keywords identified
  ...

All 8 research dimensions complete ($3.40). Generating roadmap...

Proposed milestones:
  M1: Foundation — scaffold, DB schema, auth, design system ($6)
  M2: Bank Sync — Plaid integration, transaction import ($8)
  M3: Core Pages — dashboard, category breakdown, trends ($10)
  M4: SEO & Content — blog, structured data, sitemaps ($7)
  M5: Monetization — ads, leads, insurance widgets ($8)
  M6: Polish & Launch — performance, a11y, PWA, deploy ($6)

Total estimate: ~$45. Approve this roadmap? Any changes?

> Looks great. Let's go. Milestone pause mode.

Starting M1: Foundation...
  Decomposing into stories...
  Story 1/4: Scaffold Next.js project with design system
  Dispatching implementer agent (background)...

  ◐ Story 1 implementing...

> Oh wait, I want to use Poppins for headings and Inter for body text

Got it — saved to project DNA. The implementer will pick this up
from the design system story. No need to restart anything.

  ✓ Story 1 complete: DONE (scaffold + design tokens + Poppins/Inter)
  Dispatching QA reviewer...
  ✓ QA: APPROVED on first pass
  Committing: "feat(M1): scaffold with design system, Poppins/Inter typography"

  Story 2/4: Database schema + Supabase setup
  Dispatching implementer agent (background)...
  ◐ Story 2 implementing...

> Can you show me what the design tokens look like?

Here's what was created in src/app/globals.css:
  --guru-navy-900: #0a1628
  --guru-green-500: #22c55e
  --font-poppins: 'Poppins', sans-serif
  --font-inter: 'Inter', sans-serif
  [... shows relevant code snippet ...]

  ✓ Story 2 complete: DONE
  ✓ QA: APPROVED
  ...

M1 COMPLETE (4 stories, $5.80, 42 min)

Milestone 1 summary:
  ✓ Next.js 16 scaffold with design system
  ✓ Supabase schema (accounts, categories, transactions)
  ✓ Auth setup (admin middleware)
  ✓ CI pipeline (tsc + vitest + lint)
  Tests: 12 passing
  Token spend: $5.80 / $45 budget

Continue to M2: Data Pipeline? [yes/pause/skip/adjust]

> Yes, continue. But for M2, make sure the scrapers use Playwright,
  not Puppeteer.

Noted — Playwright requirement added to M2 context. Starting M2...
```

### Notes System (`.maestro/notes.md`)

User messages during execution are saved to a living notes file:

```markdown
# Magnum Opus Notes

## User Inputs (captured during execution)

### M1: Foundation
- [2026-03-17 10:15] Typography: Poppins headings, Inter body
- [2026-03-17 10:22] Design inspiration: copilot.money

### M2: Bank Sync
- [2026-03-17 11:05] Requirement: Use Plaid for bank connections, not manual CSV
- [2026-03-17 11:30] Reference: plaid.com/docs for transaction categorization API

### General
- [2026-03-17 10:45] Revenue: insurance leads are highest priority
```

The orchestrator injects relevant notes into each story's context. Notes tagged with a milestone are injected for that milestone's stories. General notes are available to all.

### Interrupt vs. Non-Interrupt

The orchestrator classifies user messages into two categories:

**Non-interrupting** (most messages): Information, context, feedback, questions.
These are saved to notes and incorporated at the next natural breakpoint (between stories). Current background agents keep working.

**Interrupting** (explicit or urgent): "STOP", "pause now", "fix this bug immediately".
These trigger:
1. Wait for current background agent to finish (or kill it if truly urgent)
2. Save all state
3. Process the interrupt (create urgent story, pause, redirect)
4. Resume or wait for user

The orchestrator uses these signals to classify:
- "STOP", "PAUSE", "URGENT", "CRITICAL", "NOW" → interrupt
- "also", "by the way", "when you get to", "for future reference" → non-interrupt
- Ambiguous → ask: "Should I pause current work for this, or queue it for later?"

### Divergence Support

The user can fundamentally redirect the project mid-flight:

```
> Actually, forget the full dashboard. Let's pivot to a
  simple expense tracker mobile app instead.

That's a significant pivot. Here's what I suggest:

  Option 1: Full restart — new vision, new research, new roadmap
  Option 2: Pivot from current position — keep M1 foundation,
            replace M2-M6 with new milestones for expense tracker
  Option 3: Branch — keep current work on a branch, start
            expense tracker as a new Magnum Opus session

Which approach? [1/2/3]

> Option 2 — keep the foundation

Got it. Let me update the vision and generate new milestones
for the expense tracker pivot. Keeping M1 foundation work intact.

Updating vision.md... ✓
Archiving old roadmap to .maestro/archive/roadmap-v1.md... ✓
Generating new milestones...
  M2: Expense Capture (quick-add, receipt scan, categories)
  M3: Reports & Insights (weekly/monthly summaries, trends)
  M4: Sync & Export (bank sync, CSV export, backup)
  M5: Mobile PWA & Launch

New roadmap approved? [yes/adjust]
```

---

### The `/maestro opus` Command

```
/maestro opus "description"
  [--full-auto]           # No stops between milestones
  [--milestone-pause]     # Pause between milestones (default)
  [--budget $N]           # Token budget cap
  [--hours N]             # Time cap
  [--until-pause]         # Run until /maestro pause
  [--skip-research]       # Skip mega research (use existing)
  [--milestones M1,M2]    # Only execute specific milestones
  [--start-from M3]       # Resume from specific milestone
  [--resume]              # Resume from state file
```

Also available as `/maestro magnum-opus` (alias) for those who love the full name.

```
USER: /maestro "Build spending dashboard like NerdWallet"
        │
        ▼
  ┌─ CLASSIFY ─┐
  │ Mentions competitors/market → research first
  │ Mentions architecture/design → arch first
  │ Mentions marketing/growth   → strategy
  │ Otherwise                   → plan + build
  └─────────────┘
        │
        ▼
  [FORECAST] Analyze complexity, estimate token cost
  "This feature: ~$3.80 (5 stories, recommended: 70% Sonnet / 30% Opus)"
  User confirms budget
        │
        ▼
  [RESEARCH] (if needed) Web + Playwright + technical analysis
  Output: .maestro/research.md (competitor matrix, screenshots, patterns)
        │
        ▼
  [ARCHITECTURE] (if needed) Design/update .maestro/architecture.md
  Uses: feature-dev:code-architect for analysis, project DNA for context
        │
        ▼
  [SKILLS] (if needed) Auto-create project specialists
  Uses: skill-creator for validation, profiles/ as templates
        │
        ▼
  [DECOMPOSE] Break into 2-8 stories with dependency graph
  Output: .maestro/stories/01-slug.md ... NN-slug.md
  User approves story list + dependency order
        │
        ▼
  [ASK MODE] "How should I handle these stories?"
  [1] Yolo — auto all   [2] Checkpoint — per story   [3] Careful — per phase
        │
        ▼
  [SETUP WORKTREE] via superpowers:using-git-worktrees pattern
  Create feature branch + isolated workspace
        │
        ▼
  FOR EACH STORY (respecting dependency order):
  ┌──────────────────────────────────────────────────────────────┐
  │ Phase 1: VALIDATE    — check deps, files, prerequisites      │
  │ Phase 2: DELEGATE    — craft role-specific prompt + context   │
  │ Phase 3: IMPLEMENT   — subagent (TDD, isolation: worktree)   │
  │ Phase 4: SELF-HEAL   — tsc + lint + test (auto-fix, max 3x)  │
  │ Phase 5: QA REVIEW   — different subagent (max 5 rejects)    │
  │ Phase 6: GIT CRAFT   — detailed documentation-quality commit  │
  │ Phase 7: CHECKPOINT  — GO/PAUSE/ABORT (or auto in yolo mode)  │
  │                                                                │
  │ Error Recovery:                                                │
  │   QA rejects 5x  → PAUSE + show feedback + ask user           │
  │   Self-heal 3x   → PAUSE + show errors + suggest manual fix   │
  │   ABORT           → revert story changes + update state        │
  │   SKIP            → mark skipped + move to next story          │
  └──────────────────────────────────────────────────────────────┘
        │
        ▼
  [PREVIEW] (if UI story) Chrome: screenshot + user verification
        │
        ▼
  [SHIP] Final verification → PR with full summary
  Uses: pr-review-toolkit:review-pr for quality gate
  Update: .maestro/state.md, roadmap.md, token-ledger.md
        │
        ▼
  [RETROSPECTIVE] Self-improvement
  What worked? What failed? Update skills + journal
```

---

## Plugin Compatibility Design

### How Maestro Coexists With Superpowers

Maestro follows superpowers conventions where they overlap:

**Implementer Status Protocol** (from superpowers:subagent-driven-development):
- `DONE` — proceed to QA review
- `DONE_WITH_CONCERNS` — read concerns, address if needed, then QA
- `NEEDS_CONTEXT` — provide missing context, re-dispatch
- `BLOCKED` — assess blocker, escalate if needed

**Worktree Convention** (from superpowers:using-git-worktrees):
- Check `.worktrees/` → `worktrees/` → CLAUDE.md → ask user
- Verify directory is gitignored
- Auto-detect project setup (npm install, etc.)
- Verify clean test baseline

**Plan Format** (compatible with superpowers:writing-plans):
- Stories use checkbox syntax (`- [ ]`) for tracking
- Each story has Files, Steps, Expected output sections
- Plans include header with Goal, Architecture, Tech Stack

**What Maestro Adds (doesn't exist in superpowers):**
- Strategy & Research layers
- Token cost tracking and forecasting
- Competitive intel with Playwright
- Self-improvement retrospectives
- Interactive mode selection per story
- Living project documentation
- Progressive trust system

### How Maestro Coexists With Ralph Loop

- **Different state files:** `.maestro/state.local.md` vs `.claude/ralph-loop.local.md`
- **Different stop hooks:** Each reads only its own state file
- **Session isolation:** Both use `session_id` to avoid cross-session interference
- **User can use both:** Ralph for simple loops, Maestro for full orchestration

### How Maestro Uses Skill Creator

Skill Factory doesn't reinvent skill creation — it delegates:

1. Analyze project (CLAUDE.md, tech stack, domain)
2. Select relevant profile template from `profiles/`
3. Customize with project specifics
4. Call skill-creator for validation
5. If available, use skill-creator's description optimization
6. Write to project's `.claude/skills/<name>/SKILL.md`

---

## CONTEXT ENGINE — Optimal Context Management (Critical Architecture)

### The Problem

LLMs degrade with too much context. Research and practice show:

1. **Attention dilution** — irrelevant context buries the important details
2. **Conflicting instructions** — too many rules cause the model to miss or misapply them
3. **Recency bias** — earlier context gets less attention in long prompts
4. **Context pollution** — orchestrator reasoning leaks into agent thinking
5. **Token waste** — paying for context the agent never uses

A naive orchestrator dumps everything into every agent. Maestro's Context Engine does the opposite: **each agent gets exactly what it needs to perform brilliantly — no more, no less.**

### The Enterprise Analogy

```
┌─────────────────────────────────────────────────────────────────────┐
│  T0: CEO / ORCHESTRATOR                                             │
│  Sees: Everything — vision, strategy, research, roadmap,            │
│        architecture, all stories, all agent results, trust metrics  │
│  Context budget: 15-25K tokens                                      │
│  Why: Needs the full picture to make routing and priority decisions  │
├─────────────────────────────────────────────────────────────────────┤
│  T1: CTO / STRATEGIC AGENTS (strategist, researcher)                │
│  Sees: Vision, research docs, roadmap, competitive intel,           │
│        market data, high-level architecture                         │
│  Does NOT see: Implementation details, file contents, test code     │
│  Context budget: 10-15K tokens                                      │
│  Why: Needs broad strategic context, not code-level details         │
├─────────────────────────────────────────────────────────────────────┤
│  T2: LEAD ARCHITECT / ARCHITECTURE AGENTS                           │
│  Sees: Architecture doc, component map, API design, data model,     │
│        relevant milestone scope, tech stack constraints             │
│  Does NOT see: Marketing strategy, competitive research,            │
│        monetization details, unrelated milestone stories            │
│  Context budget: 8-12K tokens                                       │
│  Why: Needs system-level understanding, not business context        │
├─────────────────────────────────────────────────────────────────────┤
│  T3: SENIOR DEV / IMPLEMENTER + QA AGENTS                          │
│  Sees: Story spec, acceptance criteria, relevant file contents,     │
│        interface definitions, coding patterns for THIS task,        │
│        CLAUDE.md rules (relevant subset only)                       │
│  Does NOT see: Other stories, roadmap, research, strategy,          │
│        architecture (beyond interfaces), orchestrator reasoning     │
│  Context budget: 4-8K tokens                                        │
│  Why: Focused scope = better code. Less distraction = fewer bugs    │
├─────────────────────────────────────────────────────────────────────┤
│  T4: SPECIALIST / SELF-HEAL + FIX AGENTS                            │
│  Sees: Error message, affected file(s), fix pattern, test output    │
│  Does NOT see: Story spec, other files, project context             │
│  Context budget: 1-3K tokens                                        │
│  Why: Laser-focused on ONE problem. Maximum signal-to-noise         │
└─────────────────────────────────────────────────────────────────────┘
```

### Context Composition Pipeline

For every agent dispatch, the Context Engine runs a 5-step pipeline:

```
STEP 1: CLASSIFY ROLE                    STEP 2: SELECT TIER
  What kind of agent?          →          Which context tier?
  implementer / qa-reviewer /             T0-T4 determines budget
  researcher / strategist /               and scope boundaries
  self-heal / architect

              │                                    │
              ▼                                    ▼

STEP 3: RELEVANCE FILTER                 STEP 4: COMPOSE PACKAGE
  From the tier's available    →          Assemble context in order:
  context, score relevance                1. Task instructions
  to THIS specific task.                  2. Constraints (rules)
  Story says "API route" →                3. Patterns (relevant only)
  include API patterns,                   4. File contents (targeted)
  exclude UI patterns.                    5. History (if relevant)

              │                                    │
              ▼                                    ▼

STEP 5: BUDGET CHECK
  Total tokens within tier budget?
  YES → dispatch agent
  NO  → trim lowest-relevance items until within budget
```

### What Each Tier Gets (Detailed)

**T3: Implementer Agent (typical story)**

```markdown
## Your Task
[Story spec: 300 tokens]

## Project Rules (for this task)
[Relevant CLAUDE.md subset: 200 tokens]
  - "Use cn() for Tailwind classes"
  - "Named exports, no default exports"
  - "Server Components by default"
  (NOT: "Never modify supabase.ts" — irrelevant if story doesn't touch data layer)

## Coding Patterns
[From Project DNA, filtered by story type: 300 tokens]
  - API route pattern: Zod validation + withRateLimit()
  - Response format: Cache-Control headers via CACHE_HEADERS
  (NOT: component patterns, styling patterns — this is a backend story)

## Interfaces
[Only types/interfaces this story touches: 400 tokens]
  - Transaction type definition
  - SpendingSummary type (to create)
  (NOT: all 50+ types in transactions.ts)

## Files to Reference
[Exact file contents, targeted sections: 1500 tokens]
  - src/app/api/v1/transactions/route.ts (pattern to follow)
  - src/lib/cache/rate-limit.ts:15-40 (withRateLimit usage)
  (NOT: entire files, NOT: unrelated files)

## QA Patterns to Avoid
[From previous QA feedback on similar stories: 200 tokens]
  - "Always add rate limit test" (rejected twice before)
  - "Use Zod safeParse, not parse" (common correction)

TOTAL: ~2,900 tokens
```

**vs. Naive approach (dump everything):**

```markdown
## Full CLAUDE.md: 4,000 tokens
## Full Project DNA: 2,000 tokens
## Full architecture.md: 3,000 tokens
## All type definitions: 2,500 tokens
## All referenced files (full): 8,000 tokens
## All QA history: 1,500 tokens
## Roadmap context: 1,000 tokens
## Research context: 2,000 tokens

TOTAL: ~24,000 tokens  ← 8x more, WORSE performance
```

**The Context Engine achieves 70-85% token reduction per agent dispatch while IMPROVING code quality** because the agent focuses on what matters.

### Relevance Scoring

For each piece of available context, the engine scores relevance to the current task:

| Signal | High Relevance (include) | Low Relevance (exclude) |
|--------|-------------------------|------------------------|
| **Story type** | Backend story → API patterns, DB schema | Backend story → UI patterns, animations |
| **Story files** | `src/app/api/*` → API conventions | `src/app/api/*` → component conventions |
| **Story keywords** | "rate limiting" → cache/rate-limit rules | "rate limiting" → SEO rules |
| **Previous failures** | Same story type QA rejections | Different story type rejections |
| **CLAUDE.md rules** | Rules mentioning affected files/patterns | Rules about unrelated areas |
| **Types/interfaces** | Types imported by affected files | Types in unrelated modules |

The scoring uses simple keyword matching + file path analysis — no ML needed. Fast, deterministic, predictable.

### Context Budget Allocation

Budgets are guidelines, not hard limits. The engine trims from lowest-relevance items first.

| Agent Type | Base Budget | Breakdown |
|------------|------------|-----------|
| **Orchestrator (T0)** | 15-25K | Vision(1K) + Roadmap(1K) + State(500) + DNA(1K) + Research(3K) + Architecture(2K) + Stories(3K) + Notes(500) + Trust(200) |
| **Strategist (T1)** | 10-15K | Vision(1K) + Research(5K) + Roadmap(1K) + Market(3K) + Competitive(2K) |
| **Architect (T2)** | 8-12K | Architecture(2K) + DNA(1K) + Data Model(2K) + API Design(1.5K) + Milestone Scope(1.5K) + Constraints(500) |
| **Implementer (T3)** | 4-8K | Story(300) + Rules(200) + Patterns(300) + Interfaces(400) + Files(2K) + QA History(200) |
| **QA Reviewer (T3)** | 4-6K | Story(300) + Diff(2K) + Rules(200) + Patterns(200) + Test Output(500) |
| **Self-Heal (T4)** | 1-3K | Error(200) + File(1K) + Fix Pattern(200) |

### Token Savings Per Magnum Opus Session

For a typical 5-milestone, 25-story Magnum Opus run:

| Approach | Context per Agent | Agents Dispatched | Total Context Tokens | Cost |
|----------|------------------|-------------------|---------------------|------|
| **Naive (dump everything)** | ~24K | 50+ (impl + QA + heal) | ~1.2M | $18-36 |
| **Context Engine** | ~4-6K avg | 50+ | ~250-300K | $3.75-9 |
| **Savings** | | | **75-80% reduction** | **$14-27 saved** |

Over a Magnum Opus session, the Context Engine can **save $15-25 in token costs** while producing better results.

### How Context Engine Prevents Model Degradation

| Degradation Pattern | How Context Engine Prevents It |
|--------------------|-----------------------------|
| **Attention dilution** | Only relevant context = model focuses on what matters |
| **Needle in haystack** | Small, targeted context = no buried information |
| **Conflicting instructions** | Only applicable rules = no contradictions |
| **Context window pressure** | 4-8K per agent vs 24K = room for model reasoning |
| **Recency bias** | Task instructions first, context second = correct priority |
| **Hallucination from excess context** | Less irrelevant info = less to hallucinate about |
| **Goal drift** | North Star + focused scope = stays on task |

### Context Engine in the Plugin Structure

```
skills/
  context-engine/
    SKILL.md                    # Core context composition logic
    references/
      tier-definitions.md       # T0-T4 scope definitions
      relevance-rules.md        # Keyword → context mapping rules
      budget-profiles.md        # Token budgets per agent type
```

The Context Engine is invoked by the Delegation Protocol before every agent dispatch. It's the layer between "what context exists" and "what context this agent receives."

### Integration with Delegation Protocol

```
Story arrives for implementation
        │
        ▼
  ┌─ DELEGATION PROTOCOL ───────────────────────────────┐
  │                                                      │
  │  1. Classify: backend story, API route, 2 files      │
  │  2. Select model: sonnet (mechanical, clear spec)    │
  │                                                      │
  │  ┌─ CONTEXT ENGINE ──────────────────────────────┐   │
  │  │                                                │   │
  │  │  3. Tier: T3 (implementer)                     │   │
  │  │  4. Budget: 5K tokens                          │   │
  │  │  5. Relevance filter:                          │   │
  │  │     ✓ API patterns (story type = backend)      │   │
  │  │     ✓ Rate limiting rules (story mentions it)  │   │
  │  │     ✓ Zod validation pattern (API convention)  │   │
  │  │     ✗ Design system tokens (irrelevant)        │   │
  │  │     ✗ SEO patterns (irrelevant)                │   │
  │  │     ✗ Monetization rules (irrelevant)          │   │
  │  │  6. Compose: task + rules + patterns + files   │   │
  │  │  7. Budget check: 3.2K / 5K ✓                  │   │
  │  │                                                │   │
  │  └────────────────────────────────────────────────┘   │
  │                                                      │
  │  8. Dispatch implementer with composed context       │
  │     model: sonnet                                    │
  │     isolation: worktree                              │
  │     context: [3.2K tokens, precisely crafted]        │
  │                                                      │
  └──────────────────────────────────────────────────────┘
```

### Adaptive Escalation

When an implementer returns `NEEDS_CONTEXT`, the Context Engine escalates:

1. **First escalation:** Add next-relevance items from the tier (e.g., add related types, add architecture section)
2. **Second escalation:** Promote to T2 budget (give more architectural context)
3. **Third escalation:** Human in the loop — "The implementer needs more context. What else should it know?"

This prevents both under-contexting (agent can't do the work) and over-contexting (dump everything).

### Model Selection (Enhanced with Context Awareness)

| Task Complexity | Signal | Model | Context Tier |
|----------------|--------|-------|-------------|
| Trivial | 1 file, simple change, clear pattern | `haiku` | T4 (1-3K) |
| Mechanical | 1-2 files, clear spec, boilerplate | `sonnet` | T3 (4-6K) |
| Integration | Multi-file, pattern matching | `sonnet` | T3 (6-8K) |
| Architecture/Design | System-level judgment | `opus` | T2 (8-12K) |
| Strategic/Research | Broad analysis, planning | `opus` | T1 (10-15K) |

**Model + Context Tier = optimal cost and quality.** A haiku agent with 1.5K tokens of focused context outperforms an opus agent with 24K tokens of noise.

---

## Delegation Protocol (Built on Context Engine)

The Delegation Protocol is the orchestrator's decision layer for every agent dispatch. It answers three questions:

1. **Who?** — Which agent type handles this task (implementer, QA, researcher, strategist)
2. **What model?** — Haiku for trivial, Sonnet for mechanical, Opus for judgment (see Model Selection above)
3. **What context?** — Context Engine composes the right-sized package (see tiers above)

The protocol also handles agent responses:
- `DONE` → proceed to next phase
- `DONE_WITH_CONCERNS` → read concerns, address if needed
- `NEEDS_CONTEXT` → Context Engine escalates (add more context, bump tier)
- `BLOCKED` → assess blocker, re-dispatch with more capable model, or escalate to user

The Context Engine is invoked on EVERY dispatch. No agent ever receives unfiltered context.

---

## Cost Tracking Engine (Optional — Killer Feature)

Maestro's cost tracking is a **two-part system** that can be turned on or off independently:

### 1. Forecast (Pre-Execution Estimate)

Before spending tokens, Maestro estimates cost:

```
/maestro "Add spending dashboard like NerdWallet"

Analyzing complexity...

Forecast:
  Stories: 5 (3 backend, 1 frontend, 1 integration)
  Estimated tokens: ~185,000
  Estimated cost: ~$3.80
  Model mix: 70% Sonnet ($0.54/story avg) / 30% Opus ($1.90 for QA)

  Breakdown:
    Research:     ~15K tokens  ($0.23)  — competitor analysis
    Architecture: ~8K tokens   ($0.12)  — design doc update
    Decompose:    ~5K tokens   ($0.08)  — story creation
    Stories (5x): ~145K tokens ($3.05)  — implementation + QA
    Ship:         ~12K tokens  ($0.32)  — PR + changelog

  Savings tip: Use --yolo to skip checkpoints (-15% tokens)

Proceed? [Y/n]
```

**How it estimates:**
1. Classify task complexity (simple/medium/complex)
2. Estimate story count from similar past features (from journal)
3. Apply per-story token averages from token ledger history
4. Adjust for model mix and mode (yolo vs checkpoint)

### 2. Token Ledger (Post-Execution Tracking)

After each story and feature, logs actual token usage to `.maestro/token-ledger.md`.

### On/Off Configuration

The cost tracking engine is **optional**. Turning it off saves the tokens that would be spent on estimating, tracking, and reporting costs.

```yaml
# .maestro/config.yaml
cost_tracking:
  enabled: true          # Master switch (default: true)
  forecast: true         # Show estimates before execution (default: true)
  ledger: true           # Track actual spend per story (default: true)
  budget_enforcement: true  # Pause when budget exceeded (default: true)
```

**Override per invocation:**

```
/maestro "Add login page" --no-cost-tracking     # Disable all cost tracking
/maestro "Add login page" --no-forecast           # Skip forecast, keep ledger
/maestro opus "Build SaaS" --budget $50           # Implies all tracking ON
```

| Setting | What's Saved | What's Lost |
|---------|-------------|-------------|
| **All ON** (default) | Nothing — full visibility | ~500-1000 tokens per feature on tracking overhead |
| **Ledger only** (no forecast) | Forecast tokens (~200-500) | Pre-execution cost estimate |
| **All OFF** | All tracking overhead (~500-1000 tokens) | Cost visibility, budget enforcement, spending history |

**Recommendation:** Keep it ON for Magnum Opus sessions (budget enforcement is a safety valve). For quick single-feature runs, `--no-forecast` skips the estimate while still tracking actual spend. Only use `--no-cost-tracking` for rapid prototyping where every token counts.

**When OFF, these features are disabled:**
- Forecast before execution
- Token spend display at checkpoints
- Budget cap enforcement (dangerous in Magnum Opus mode!)
- Token ledger history for future estimates
- Cost data in build logs and PR summaries

**When ON, the overhead is minimal:** ~500-1000 tokens per feature (~$0.01-0.02). The forecast itself costs less than the information it provides.

---

## Maestro Watch (Killer Feature)

Continuous monitoring using Claude Code's CronCreate:

```
/maestro watch --every 30m

Monitoring started:
  [x] Test suite (npm test)
  [x] TypeScript check (tsc --noEmit)
  [x] Lighthouse (if dev server running)
  [ ] Broken links (disabled — no sitemap)

  Notifications: terminal + .maestro/watch.log
  Auto-create stories: enabled (when issues found)
```

**Uses CronCreate** to schedule periodic checks. When issues found:
1. Log to `.maestro/watch.log`
2. If severity > threshold, auto-create a story in `.maestro/stories/`
3. Notify user at next interaction

---

## Project DNA (Killer Feature)

Auto-generated project understanding, stored in `.maestro/dna.md`:

```markdown
# Project DNA — FinTrack

## Tech Stack
- Framework: Next.js 16 (App Router) + React 19
- Styling: Tailwind CSS 4 (CSS custom properties)
- Database: Supabase (PostgreSQL)
- Payments: Stripe (subscriptions)
- Bank Sync: Plaid API

## Patterns Detected
- Server Components by default ('use client' only when needed)
- cn() utility for Tailwind class merging
- Zod validation on all API routes
- Recharts for data visualization
- React Hook Form + Zod for forms

## Architecture Layers
- Pages: src/app/**/page.tsx (Server Components)
- Components: src/components/{ui,layout,dashboard,charts,...}
- Data: src/lib/data/ (DO NOT MODIFY)
- Business: src/lib/business/ (no DB deps)
- API: src/app/api/** (rate-limited, Zod-validated)

## Conventions
- Named exports, no default exports
- One component per file
- CSS variables for design tokens
- 8px grid spacing system
- Inter font family throughout

## Sensitive Areas
- src/lib/data/supabase*.ts — NEVER modify
- src/types/transactions.ts — NEVER modify
- Stripe webhook handlers — modify with extreme care
- User financial data — encrypt at rest, never log
```

**Auto-generated** by reading CLAUDE.md, package.json, tsconfig.json, directory structure, and recent commits. Updated when project changes significantly.

**Why this matters:** Every subagent gets project-specific context without reading the entire codebase. The frontend implementer knows "use cn() for Tailwind" and "Server Components by default" before writing a single line.

---

## Progressive Trust (Killer Feature)

Maestro tracks its own reliability in `.maestro/trust.yaml`:

```yaml
total_stories: 0
qa_first_pass_rate: 0.00
self_heal_success_rate: 0.00
average_qa_iterations: 0.0
stories_by_mode:
  yolo: 0
  checkpoint: 0
  careful: 0
```

**Trust levels:**

| Level | Criteria | Behavior |
|-------|----------|----------|
| **Novice** | < 5 stories completed | Default: careful mode. Always ask |
| **Apprentice** | 5-15 stories, QA pass > 60% | Default: checkpoint. Suggest yolo for simple stories |
| **Journeyman** | 15-30 stories, QA pass > 75% | Default: checkpoint. Auto-yolo for < 2 file stories |
| **Expert** | 30+ stories, QA pass > 85% | Default: yolo. Only checkpoint for complex/sensitive |

Trust is per-project, not global. A project with many successful stories earns more autonomy.

---

## Self-Learning Loop (Killer Feature — claude-coach + claude-reflect + claude-meta)

The most sophisticated self-improvement system in any Claude Code plugin, combining 3 community patterns:

### Phase 1: Friction Detection (from claude-coach)

After every feature completion, Maestro scans the session for 6 signal types:

| Signal | Detection | Example |
|--------|-----------|---------|
| `COMMAND_FAILURE` | Tool/command failures in transcript | `tsc --noEmit` fails 3x on same pattern |
| `USER_CORRECTION` | "no, use X instead", "actually..." | "Don't use default exports" |
| `SKILL_SUPPLEMENT` | User adds guidance on top of skills | "Also check for a11y when building components" |
| `VERSION_ISSUE` | Deprecated tools/outdated deps | Using old Tailwind syntax |
| `REPETITION` | Same instruction across sessions | "Remember to use cn() for classes" |
| `TONE_ESCALATION` | User frustration signals | "I already told you..." |

### Phase 2: Improvement Proposal (from claude-reflect)

Each friction signal generates a candidate with confidence score (0.60-0.95):

```yaml
signal_type: USER_CORRECTION
confidence: 0.85
observation: "User corrected 'use default exports' to 'use named exports' 3 times"
proposed_improvement:
  type: rule  # rule | checklist | snippet | skill | antipattern
  target: implementer-prompt.md
  change: "Add to implementer instructions: 'Always use named exports. No default exports.'"
  why: "Project convention — CLAUDE.md says 'No default exports'"
```

### Phase 3: Meta-Rules (from claude-meta)

The retrospective skill contains meta-rules that teach Maestro HOW to write good improvements:

```markdown
## Meta-Rules for Self-Improvement

1. Generalize from specific corrections. "Use cn() for classes" → "Follow project's utility function conventions"
2. Explain WHY, not just WHAT. "Use named exports" + "because the project convention in CLAUDE.md requires it"
3. Don't add MUSTs in all caps. Explain reasoning so agents understand edge cases.
4. Check if the improvement already exists before adding duplicates.
5. Remove improvements that aren't pulling their weight (no friction signals for 10+ stories).
```

### Phase 4: Approval & Application

Improvements are **never applied silently** (claude-coach safety pattern):

```
Retrospective complete. Found 3 improvements:

1. [0.85] Add to implementer prompt: "Always use named exports"
   Reason: corrected 3 times in this feature

2. [0.72] Add to QA checklist: "Verify a11y attributes on interactive elements"
   Reason: user supplemented a11y guidance twice

3. [0.60] Update self-heal: "Run 'npm run lint --fix' before tsc"
   Reason: lint errors caused 4 self-heal cycles

Apply? [all/1,2/none]
```

### Where Improvements Are Applied

| Target | What Changes |
|--------|-------------|
| `agents/implementer.md` | Dev agent instructions |
| `agents/qa-reviewer.md` | QA review checklist |
| `skills/dev-loop/SKILL.md` | Phase behavior |
| `.maestro/journal.md` | Learnings log |
| `.maestro/trust.yaml` | Trust metrics |
| Project CLAUDE.md | Critical project rules (with user consent) |

---

## Opus Quality Gate (Killer Feature — from claude-swarm)

After ALL stories in a feature are implemented, before shipping:

```
All 4 stories complete. Running quality gate...

Dispatching Opus quality gate agent (read-only)...

Quality Gate Report:
  Correctness:   PASS — All acceptance criteria met
  Consistency:   PASS — Code follows project patterns
  Integration:   WARN — Story 3 and Story 4 both define `formatPrice()` helper
  Security:      PASS — No OWASP issues found
  Edge Cases:    WARN — Summary API has no rate limit test

Recommendations:
  1. Deduplicate formatPrice() — keep the one in src/lib/utils.ts
  2. Add rate limit test for compare API endpoint

Fix before shipping? [yes/skip/manual]
```

The quality gate agent:
- Uses `model: opus` for maximum judgment
- Is **read-only** (no edits, only analysis)
- Reviews the COMBINED diff of all stories against main
- Checks: correctness, consistency, integration, security, edge cases
- Produces actionable recommendations
- User decides whether to fix, skip, or handle manually

---

## North Star Anchoring (Killer Feature — from self-evolving-agent)

Long autonomous runs (5+ stories, 30+ minutes) risk **goal drift** — the agent gradually loses focus on the original feature request. Maestro prevents this by re-injecting the North Star at each phase transition:

```markdown
## North Star (re-injected at each phase)

Feature: "Add monthly spending dashboard with charts"
Goal: Users can view spending trends, category breakdowns, and budget vs actual
Success: GET /api/v1/summary works, UI shows spending dashboard, tests pass

Current progress: Story 3/5 complete. Stories 1-3 built the API layer.
This story (4): Build the comparison UI component.
Next story (5): Integration tests + Chrome preview.

Stay focused on THIS story's acceptance criteria. Do not refactor unrelated code.
```

The prompt includes:
1. Original feature description (immutable)
2. Overall progress context
3. Current story's specific scope
4. Explicit boundary: "Do not refactor unrelated code"

---

## Persistent Agent Memory (Killer Feature — Claude Code Native)

Claude Code supports `memory: project` in agent frontmatter. This means agents maintain persistent MEMORY.md files that survive across sessions.

**How Maestro uses this:**

```yaml
# agents/implementer.md
---
name: maestro-implementer
memory: project
---
```

Over time, the implementer learns:
- "This project uses cn() for Tailwind class merging"
- "Tests are in src/lib/__tests__/, not __tests__/"
- "API routes use withRateLimit() pattern"
- "The user prefers explicit error handling over try/catch silence"

**The result:** After 10+ features, the implementer produces code that matches your project's patterns on the first try. QA pass rate goes up. Token cost goes down. The system gets better the more you use it.

---

## Revised Plugin Structure

```
maestro/
├── .claude-plugin/
│   └── plugin.json                    # Plugin metadata (v1.0.0)
│
├── commands/                          # Slash commands (user-facing)
│   ├── maestro.md                     # /maestro — main entry, auto-routes
│   ├── maestro-init.md                # /maestro-init — project initialization
│   ├── maestro-auto.md                # /maestro-auto — autonomous product builder
│   ├── maestro-status.md              # /maestro-status — view/resume/abort/pause
│   └── maestro-model.md               # /maestro-model — view/edit model config
│
├── skills/                            # Internal skills (invoked by commands)
│   ├── classifier/
│   │   └── SKILL.md                   # Auto-classify intent → route to layer
│   ├── forecast/
│   │   └── SKILL.md                   # Token cost estimation before execution
│   ├── research/
│   │   └── SKILL.md                   # Competitive intel (web + playwright)
│   ├── architecture/
│   │   └── SKILL.md                   # Design/update architecture doc
│   ├── strategy/
│   │   └── SKILL.md                   # Marketing & growth strategy
│   ├── decompose/
│   │   ├── SKILL.md                   # Story decomposition with deps
│   │   └── story-template.md          # Story file template
│   ├── skill-factory/
│   │   └── SKILL.md                   # Auto-create specialist skills
│   ├── context-engine/                # Optimal context management
│   │   ├── SKILL.md                   # Context composition pipeline
│   │   └── references/
│   │       ├── tier-definitions.md    # T0-T4 scope definitions
│   │       ├── relevance-rules.md     # Keyword → context mapping
│   │       └── budget-profiles.md     # Token budgets per agent type
│   ├── delegation/
│   │   └── SKILL.md                   # Role-specific dispatch protocol
│   ├── dev-loop/
│   │   ├── SKILL.md                   # 7-phase implementation cycle
│   │   ├── implementer-prompt.md      # Dev subagent prompt template
│   │   └── qa-reviewer-prompt.md      # QA subagent prompt template
│   ├── preview/
│   │   └── SKILL.md                   # Chrome preview & screenshot
│   ├── git-craft/
│   │   └── SKILL.md                   # Documentation-quality commits
│   ├── living-docs/
│   │   └── SKILL.md                   # Maintain vision/arch/state/roadmap
│   ├── retrospective/
│   │   └── SKILL.md                   # Self-improvement after features
│   ├── token-ledger/
│   │   └── SKILL.md                   # Token cost tracking
│   ├── build-log/
│   │   └── SKILL.md                   # Session replay / export
│   ├── project-dna/
│   │   └── SKILL.md                   # Auto-discover project patterns
│   ├── opus-loop/                     # Magnum Opus orchestration
│   │   ├── SKILL.md                   # Mega-loop (milestone-driven)
│   │   ├── deep-interview.md          # 10-dimension adaptive interview
│   │   ├── mega-research.md           # 8-dimension parallel research
│   │   ├── roadmap-generator.md       # Milestone generation
│   │   ├── milestone-evaluator.md     # Acceptance check + auto-fix
│   │   ├── conversation-channel.md    # Live message routing
│   │   └── divergence-handler.md      # Pivot / redirect support
│   ├── watch/
│   │   └── SKILL.md                   # Continuous monitoring via CronCreate
│   └── ship/
│       └── SKILL.md                   # Final verification + PR
│
├── agents/                            # Subagent prompt templates
│   ├── implementer.md                 # Dev agent (TDD, worktree isolation)
│   ├── qa-reviewer.md                 # QA agent (read-only, skeptical)
│   ├── researcher.md                  # Competitive research agent
│   └── strategist.md                  # Strategy/vision agent
│
├── profiles/                          # Specialist profile templates
│   ├── frontend-engineer.md
│   ├── backend-engineer.md
│   ├── data-engineer.md
│   ├── designer.md
│   ├── seo-specialist.md
│   ├── copywriter.md
│   ├── devops.md
│   └── security-reviewer.md
│
├── hooks/
│   ├── hooks.json                     # Stop hook config
│   └── stop-hook.sh                   # Checkpoint enforcement
│
├── templates/
│   ├── state.md                       # State doc template
│   ├── vision.md                      # Vision doc template
│   ├── architecture.md                # Architecture doc template
│   ├── roadmap.md                     # Roadmap template
│   ├── strategy.md                    # Strategy template
│   ├── dna.md                         # Project DNA template
│   └── story.md                       # Story template
│
├── scripts/
│   └── setup-maestro.sh               # Initialize .maestro/ directory
│
├── README.md                          # Community-facing docs
└── LICENSE                            # MIT
```

**Total: ~48 files across all phases**

---

## State File (`.maestro/state.local.md`)

```yaml
---
maestro_version: "1.0.0"
active: true
session_id: <uuid>
feature: "Monthly spending dashboard with charts"
mode: checkpoint
layer: execution
current_story: 2
total_stories: 5
phase: qa_review
qa_iteration: 1
max_qa_iterations: 5
self_heal_iteration: 0
max_self_heal: 3
model_override: null
worktree_path: null
started_at: "2026-03-16T17:00:00Z"
last_updated: "2026-03-16T17:30:00Z"
token_spend: 45230
estimated_remaining: 139770
---
Continue Maestro dev-loop for story 2/5.
Story: .maestro/stories/02-spending-summary-api.md
Phase: qa_review (iteration 1 of 5).
Mode: checkpoint (will ask GO/PAUSE/ABORT after this story).
```

---

## Stop Hook Design (Compatible with Ralph Loop)

```bash
#!/bin/bash
set -euo pipefail

# Read hook input from stdin
HOOK_INPUT=$(cat)

# Check if maestro is active (different state file from Ralph Loop)
MAESTRO_STATE=".maestro/state.local.md"

if [[ ! -f "$MAESTRO_STATE" ]]; then
  exit 0  # No active maestro session — allow exit
fi

# Parse frontmatter
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$MAESTRO_STATE")
ACTIVE=$(echo "$FRONTMATTER" | grep '^active:' | sed 's/active: *//')

if [[ "$ACTIVE" != "true" ]]; then
  exit 0  # Maestro not active — allow exit
fi

# Session isolation (same pattern as Ralph Loop)
STATE_SESSION=$(echo "$FRONTMATTER" | grep '^session_id:' | sed 's/session_id: *//' || true)
HOOK_SESSION=$(echo "$HOOK_INPUT" | jq -r '.session_id // ""')
if [[ -n "$STATE_SESSION" ]] && [[ "$STATE_SESSION" != "$HOOK_SESSION" ]]; then
  exit 0  # Different session — allow exit
fi

# Check mode and phase
MODE=$(echo "$FRONTMATTER" | grep '^mode:' | sed 's/mode: *//')
PHASE=$(echo "$FRONTMATTER" | grep '^phase:' | sed 's/phase: *//')
CURRENT=$(echo "$FRONTMATTER" | grep '^current_story:' | sed 's/current_story: *//')
TOTAL=$(echo "$FRONTMATTER" | grep '^total_stories:' | sed 's/total_stories: *//')

# Phases where we should block exit
case "$PHASE" in
  validate|delegate|implement|self_heal|qa_review|git_craft)
    # Autonomous phases — block in all modes
    ;;
  checkpoint|paused|completed|aborted|research|decompose)
    # Human-interactive or terminal phases — allow exit
    exit 0
    ;;
  *)
    exit 0
    ;;
esac

# Extract prompt from state file (after closing ---)
PROMPT_TEXT=$(awk '/^---$/{i++; next} i>=2' "$MAESTRO_STATE")

if [[ -z "$PROMPT_TEXT" ]]; then
  exit 0
fi

# Block exit and feed prompt back
jq -n \
  --arg prompt "$PROMPT_TEXT" \
  --arg msg "Maestro: story $CURRENT/$TOTAL, phase: $PHASE, mode: $MODE" \
  '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }'

exit 0
```

---

## Story Template (with Dependencies)

```markdown
---
id: 2
slug: spending-summary-api
title: "Add spending dashboard API endpoint"
depends_on: [1]
parallel_safe: false
estimated_tokens: 35000
model_recommendation: sonnet
type: backend
---

## Acceptance Criteria

1. GET /api/v1/summary?period=month returns spending breakdown
2. Response includes totals by category, trends, budget vs actual
3. Supports period params: week, month, quarter, year
4. Zod validation on query params
5. Rate limited via withRateLimit()
6. Unit tests covering happy path + edge cases

## Context for Implementer

- Depends on Story 1 (data fetching layer) being complete
- API patterns: see src/app/api/v1/ for existing examples
- Validation: use Zod safeParse + prettifyError
- Rate limiting: use withRateLimit() from src/lib/cache/
- Types: use Transaction from src/types/transactions.ts

## Files

- Create: `src/app/api/v1/summary/route.ts`
- Create: `src/lib/__tests__/summary-api.test.ts`
- Reference: `src/app/api/v1/transactions/route.ts` (pattern to follow)

## Definition of Done

- [ ] All acceptance criteria met
- [ ] Tests passing
- [ ] TypeScript clean (tsc --noEmit)
- [ ] Follows existing API patterns
```

---

## Phased Delivery (Revised)

### Phase 1: Core Loop + Init (MVP) — 18 files

The immediately useful, shareable MVP.

| File | Purpose | Lines (est) |
|------|---------|-------------|
| `.claude-plugin/plugin.json` | Plugin metadata v1.0.0 | 15 |
| `commands/maestro.md` | Main entry with auto-routing + interactive mode | 120 |
| `commands/maestro-init.md` | Project initialization ("wow" moment) | 80 |
| `commands/maestro-status.md` | View progress / resume / abort | 60 |
| `skills/classifier/SKILL.md` | Auto-classify intent → route | 60 |
| `skills/decompose/SKILL.md` | Story decomposition with deps | 150 |
| `skills/decompose/story-template.md` | Story file template | 40 |
| `skills/dev-loop/SKILL.md` | 7-phase implementation cycle | 250 |
| `skills/dev-loop/implementer-prompt.md` | Dev subagent prompt | 100 |
| `skills/dev-loop/qa-reviewer-prompt.md` | QA subagent prompt | 80 |
| `skills/git-craft/SKILL.md` | Documentation-quality commits | 60 |
| `skills/living-docs/SKILL.md` | Update state.md after each story | 50 |
| `skills/token-ledger/SKILL.md` | Token cost tracking (optional, on by default) | 50 |
| `agents/implementer.md` | Dev agent definition | 80 |
| `agents/qa-reviewer.md` | QA agent definition | 60 |
| `hooks/hooks.json` | Stop hook configuration | 15 |
| `hooks/stop-hook.sh` | Checkpoint enforcement | 100 |
| `templates/state.md` | State doc template | 30 |
| `scripts/setup-maestro.sh` | Initialize .maestro/ directory | 40 |
| `README.md` | Community docs | 200 |
| `LICENSE` | MIT | 21 |

**~21 files, ~1,660 lines**

**What works:** `/maestro init` → `/maestro "feature"` → decompose → dev-loop with worktrees → QA → commits → checkpoints → done. Token tracking on by default (disable with `--no-cost-tracking`).

### Phase 2: Strategy Layer + Research — 12 files

| File | Purpose |
|------|---------|
| `skills/research/SKILL.md` | Competitive intel (web + playwright) |
| `skills/strategy/SKILL.md` | Marketing & growth planning |
| `skills/architecture/SKILL.md` | Architecture design/update |
| `skills/preview/SKILL.md` | Chrome preview after implementation |
| `skills/forecast/SKILL.md` | Token cost estimation (optional, on by default) |
| `skills/project-dna/SKILL.md` | Auto-discover project patterns |
| `agents/researcher.md` | Research subagent |
| `agents/strategist.md` | Strategy subagent |
| `templates/vision.md` | Vision doc template |
| `templates/architecture.md` | Architecture doc template |
| `templates/roadmap.md` | Roadmap template |
| `templates/strategy.md` | Strategy template |

**What it adds:** Research, vision, strategy, architecture, Chrome preview, token forecasting (optional), project DNA.

### Phase 3: Context Engine + Skill Factory + Specialists — 15 files

| File | Purpose |
|------|---------|
| `skills/context-engine/SKILL.md` | Context composition pipeline (T0-T4 tiers) |
| `skills/context-engine/references/tier-definitions.md` | Scope definitions per tier |
| `skills/context-engine/references/relevance-rules.md` | Keyword → context mapping |
| `skills/context-engine/references/budget-profiles.md` | Token budgets per agent type |
| `skills/skill-factory/SKILL.md` | Auto-create project specialists (uses skill-creator) |
| `skills/delegation/SKILL.md` | Role-specific dispatch protocol (uses context-engine) |
| `profiles/frontend-engineer.md` | Template |
| `profiles/backend-engineer.md` | Template |
| `profiles/data-engineer.md` | Template |
| `profiles/designer.md` | Template |
| `profiles/seo-specialist.md` | Template |
| `profiles/copywriter.md` | Template |
| `profiles/devops.md` | Template |
| `profiles/security-reviewer.md` | Template |
| `templates/dna.md` | Project DNA template |

**What it adds:** Context Engine (70-85% token reduction per agent, prevents model degradation), auto-specialist creation, delegation protocol, profile customization. The Context Engine is the performance backbone — every agent dispatch flows through it.

### Phase 4: Magnum Opus — 12 files

The crown jewel. `/maestro opus` builds entire products from vision to launch, with live conversation.

| File | Purpose |
|------|---------|
| `commands/maestro-opus.md` | `/maestro opus` — Magnum Opus product builder |
| `skills/opus-loop/SKILL.md` | Mega-loop orchestration (milestone-driven) |
| `skills/opus-loop/deep-interview.md` | 10-dimension adaptive vision interview |
| `skills/opus-loop/mega-research.md` | 8-dimension parallel research sprint |
| `skills/opus-loop/roadmap-generator.md` | Milestone generation from vision + research |
| `skills/opus-loop/milestone-evaluator.md` | Acceptance criteria verification + auto-fix |
| `skills/opus-loop/conversation-channel.md` | Live message classification + routing |
| `skills/opus-loop/divergence-handler.md` | Pivot / redirect support |
| `skills/retrospective/SKILL.md` | Self-improvement after features |
| `skills/build-log/SKILL.md` | Session replay / exportable blog |
| `templates/milestone.md` | Milestone definition template |
| `templates/research-brief.md` | Research synthesis template |

**What it adds:** Full autonomous product building with live conversation. Deep interview → Mega research → Roadmap → Build → Evaluate → Fix → Ship. User can talk, redirect, complement without interrupting workers. "Build while I sleep, steer while I'm awake."

### Phase 5: Community + Polish — 8 files

| File | Purpose |
|------|---------|
| `skills/watch/SKILL.md` | Continuous monitoring (CronCreate) |
| `skills/ship/SKILL.md` | Final verification + PR (uses pr-review-toolkit) |
| `commands/maestro-model.md` | View/edit model assignments |
| `templates/story.md` | Story template (enhanced) |
| `CONTRIBUTING.md` | Community contribution guide |
| `CHANGELOG.md` | Version history |
| `templates/build-log-export.md` | Blog post export template |
| `templates/trust.yaml` | Trust metrics template |

**What it adds:** Monitoring, shipping, model config, community docs.

### Phase 6: Agent Teams + Parallelism (future)

- Parallel story execution across worktrees (agent teams)
- Dev + QA as teammates with shared task list
- TeammateIdle + TaskCompleted hooks for coordination
- Progressive trust auto-adjusting autonomy
- External model support via gateway
- Event-driven triggers (GitHub webhook → auto-fix PR)

---

## The "Wow" Moment: `/maestro init`

The first command a user runs. Must deliver value in < 60 seconds:

```
/maestro init

Analyzing project...

Project DNA detected:
  Framework:  Next.js 16 (App Router) + React 19
  Styling:    Tailwind CSS 4 (CSS custom properties)
  Database:   Supabase (PostgreSQL)
  Deploy:     Cloudflare Workers (OpenNext)
  Tests:      Vitest (happy-dom)
  Linting:    ESLint

  Components: 24 UI primitives, 8 page types
  API routes: 12 endpoints (rate-limited, Zod-validated)
  Pages:      94+ page types, 30K+ indexable URLs

Existing docs found:
  CLAUDE.md       ✓ (comprehensive — 180 lines)
  architecture.md ✓
  state.md        ✓

Created:
  .maestro/state.md        — Project state
  .maestro/dna.md          — Project DNA (auto-discovered)
  .maestro/token-ledger.md — Token tracking (optional, enabled by default)
  .maestro/trust.yaml      — Progressive trust (novice)

Ready! Try: /maestro "Add user reviews with star ratings"
```

---

## Token Ledger Format (when cost tracking is enabled)

`.maestro/token-ledger.md` — only created/updated when `cost_tracking.ledger: true`:

```markdown
# Maestro Token Ledger

| Date | Feature | Stories | Tokens | Cost | Model Mix | Mode | Duration |
|------|---------|---------|--------|------|-----------|------|----------|
| — | — | — | — | — | — | — | — |

## Session Log

(auto-populated after each feature when cost tracking is ON)
```

Updated after every story completion and feature ship. Skipped entirely when `--no-cost-tracking` is used.

---

## Verification Plan

### Phase 1 Verification

1. **`/maestro init`** on any project — verify auto-discovery + doc generation
2. **Smoke test:** `/maestro "Add hello API endpoint"` — 1 story, full cycle
3. **Multi-story:** `/maestro "Add monthly budget tracker"` — 3-4 stories with deps
4. **Interactive mode:** Verify AskUserQuestion offers yolo/checkpoint/careful per story
5. **Yolo mode:** Verify auto-GO between stories, stops only on failure
6. **QA rejection loop:** Force bad code, verify QA catches + fix + re-review works
7. **Error recovery:** Verify 5x QA rejection → PAUSE + user guidance
8. **Self-heal:** Verify tsc/lint auto-fix, max 3 attempts then PAUSE
9. **Git craft:** `git log` shows documentation-quality commits
10. **Resume:** PAUSE → close session → `/maestro-status resume` → continues
11. **Token ledger:** Verify costs tracked per phase/story
12. **Stop hook:** Verify coexists with Ralph Loop (both active, no conflict)
13. **Superpowers compat:** Verify implementer uses DONE/NEEDS_CONTEXT/BLOCKED protocol
14. **Worktree compat:** Verify uses superpowers worktree directory conventions

### Phase 2 Verification

15. **Research:** `/maestro research "budget tracking apps"` → screenshots + analysis
16. **Chrome preview:** UI story → screenshot shown at checkpoint
17. **Forecast:** Verify token estimate before execution
18. **Project DNA:** Verify auto-discovery matches CLAUDE.md

### Phase 3 Verification

19. **Skill factory:** Creates project specialists from profiles
20. **Delegation:** Frontend story gets design system context
21. **Profile customization:** Profile + project DNA → project-specific skill

### Phase 4 Verification (Autonomous Mode)

22. **Vision synthesis:** `/maestro opus "simple todo app"` → clarifying questions → vision.md
23. **Mega research:** 8 parallel research agents produce 8 docs in .maestro/research/
24. **Roadmap generation:** Vision + research → milestone definitions with acceptance criteria
25. **Auto execution:** Milestones execute autonomously (stories → QA → commit → next)
26. **Milestone evaluation:** Acceptance criteria checked, auto-fix stories generated for failures
27. **Budget cap:** `--budget $5` stops execution when budget reached, shows progress
28. **Time cap:** `--hours 1` stops execution after 1 hour
29. **Full auto:** `--full-auto` continues between milestones without user interaction
30. **Milestone pause:** Default pauses between milestones for user review
31. **Resume:** Close session → `/maestro opus --resume` → continues from exact position
32. **Safety:** 5 consecutive failures → PAUSE + failure log + ask user
33. **Fix cycles:** Milestone fails → auto-generate fix stories → re-evaluate (max 3 cycles)
34. **North Star:** Feature goal re-injected at each phase (verify no drift)
35. **Context management:** Long runs (>1h) don't degrade quality (fresh subagents + state file)

### Phase 5 Verification

36. **Retrospective:** After feature, verify journal + skills updated
37. **Build log:** `.maestro/logs/` has complete session record
38. **Watch:** CronCreate schedules periodic checks
39. **Ship:** PR created with full summary from stories + commits

---

## Competitive Positioning (Updated With Research)

### vs. Superpowers (v5.0.2, obra/superpowers)
- Superpowers = excellent execution layer (TDD, subagents, worktrees, 14 skills)
- Maestro = full product team (strategy + architecture + execution + monitoring + self-learning)
- **Complementary:** Maestro extends superpowers patterns. Uses same implementer protocol. Different scopes.
- **Key differentiator:** Strategy layer, research, token tracking, self-improvement

### vs. Ralph Loop (Anthropic official)
- Ralph = simple "run until done" with completion promise
- Maestro = structured orchestration with DAG stories, QA loops, interactive checkpoints
- **Complementary:** Different state files (`.maestro/` vs `.claude/ralph-loop.local.md`). Both active simultaneously.

### vs. Ruflo (v3.5, 5.8K commits, ruvnet/ruflo)
- Ruflo = enterprise-grade swarm orchestration. 60+ agents, 215 MCP tools, neural routing, WASM kernels
- Maestro = lightweight plugin. ~48 markdown files, zero runtime deps
- **Different philosophy:** Ruflo = infrastructure-heavy. Maestro = native Claude Code, zero install friction.
- **Adopted from Ruflo:** Cost-aware routing concept, RETRIEVE→JUDGE→DISTILL→CONSOLIDATE learning loop

### vs. claude-swarm (affaan-m/claude-swarm)
- claude-swarm = Python Agent SDK orchestration with Opus quality gate, htop-style terminal UI
- Maestro = Claude Code plugin, works in CLI and Desktop
- **Adopted from claude-swarm:** Dependency graph decomposition, Opus quality gate, session replay

### vs. wshobson/agents (112 agents, 72 plugins)
- wshobson = massive collection, each loads its own context
- Maestro = integrated system, not a collection. Orchestrates 4 agents with role-specific context
- **Adopted from wshobson:** Single-purpose loading pattern (low token overhead)

### vs. OpenClaw (302K stars)
- OpenClaw = always-on AI assistant via messaging platforms (WhatsApp, Telegram, Slack)
- Maestro = development orchestrator within Claude Code
- **Different audience:** OpenClaw = consumer assistant. Maestro = developer productivity.
- **Adopted from OpenClaw:** ClawHub-inspired skill sharing, always-on Watch concept

### vs. Aider (aider-ai/aider)
- Aider = standalone AI pair programmer with architect/editor split, tree-sitter repo map
- Maestro = Claude Code native plugin, strategy layer, self-improvement
- **Advantage:** Deep Claude Code integration (hooks, subagents, worktrees, agent memory)
- **Adopted from Aider:** Context relevance concept for Project DNA

### vs. Cursor Automations (March 2026)
- Cursor = IDE with event-driven agents (PR triggers, PagerDuty, Slack)
- Maestro = Claude Code plugin, same autonomous capability, different platform
- **Adopted from Cursor:** Event-driven trigger concept (Phase 5)

### vs. DevSquad (joshidikshant/devsquad)
- DevSquad = hook-enforced multi-model delegation (Claude → Gemini + Codex)
- Maestro = same model family, hook-enforced patterns
- **Critical lesson adopted:** Documentation-based rules fail after 25+ sessions. Hooks physically intercept.

### vs. claude-coach / claude-reflect / claude-meta
- Self-improvement plugins with different approaches
- Maestro = combines ALL three: coach's 6 signals + reflect's confidence scoring + meta's meta-rules
- **Advantage:** Unified self-improvement in one system, not 3 separate plugins

### The Unique Value Proposition

> "Maestro is the first Claude Code plugin that builds entire products autonomously — and lets you talk to it while it works. Deep interview, mega research, milestone-driven execution, self-learning agents, live conversation channel. Redirect mid-flight. Pivot the whole project. A self-improving product team that gets smarter every time you use it."

**The tweets that write themselves:**
- "Went to sleep. Woke up to a working SaaS dashboard. /maestro opus --full-auto --hours 8. Total cost: $47.80."
- "The craziest part of /maestro opus isn't the autonomous building. It's that I can TALK to it while it works. Said 'add dark mode' mid-flight and it just... did."
- "My /maestro implementer now passes QA 87% on first try. It literally learned my project's patterns across sessions."
- "/maestro opus interviewed me for 5 minutes, researched 12 competitors, built 23 stories across 5 milestones, shipped a PR. The deep interview is where the magic starts."
- "Mid-build I said 'actually pivot to an expense tracker' and Maestro said 'Keep the foundation, replace milestones 2-5?' The divergence handling is unreal."
- "$3.20 in tokens for product consulting. The mega research found a monetization strategy I hadn't even considered."
- "/maestro opus --budget $20 got me through 3 milestones. 'Build while I sleep, steer while I'm awake.'"

---

## Community Sharing Strategy

1. **GitHub repo** — MIT license, clean README with GIF/asciicast demos
2. **Twitter/X thread** — Token ledger screenshots + "built X for $Y" narrative
3. **awesome-claude-code** (hesreallyhim) — Submit PR
4. **awesome-claude-skills** (travisvn, 8.7k stars) — Submit profiles
5. **SkillsMP marketplace** (skillsmp.com, 500K+ skills) — Publish when available
6. **ClawHub** — Publish Maestro skills for OpenClaw compatibility
7. **Agent Skills spec** (agentskills.io) — Ensure all SKILL.md files comply with the standard
8. **Blog posts:**
   - "Building a $2.81 Feature: Inside Maestro's Three-Layer Orchestration"
   - "How My AI Agent Learned My Coding Style: Persistent Memory in Practice"
   - "From OpenClaw to Maestro: What I Learned Analyzing 20 AI Agent Projects"
9. **SQUAD.md compatibility** — Publish team definitions for Agents Squads standard
10. **Skill sharing** — `/maestro export-skills` creates shareable .skill packages

---

## Sources & Inspiration

| Project | Stars | Key Contribution to Maestro |
|---------|-------|---------------------------|
| [OpenClaw](https://github.com/openclaw/openclaw) | 302K | Always-on concept, ClawHub skill registry model |
| [Superpowers](https://github.com/obra/superpowers) | — | Implementer protocol, worktree conventions, TDD |
| [Ralph Loop](https://github.com/anthropics/claude-code) | — | Stop hook pattern, state file format, completion promise |
| [Ruflo](https://github.com/ruvnet/ruflo) | — | Cost-aware routing, learning loop pattern |
| [claude-swarm](https://github.com/affaan-m/claude-swarm) | — | DAG decomposition, Opus quality gate, session replay |
| [claude-coach](https://github.com/netresearch/claude-coach-plugin) | — | 6 friction signals, candidate taxonomy, no-silent-writes |
| [claude-reflect](https://github.com/BayramAnnakov/claude-reflect) | — | Confidence-scored capture-then-approve |
| [claude-meta](https://github.com/aviadr1/claude-meta) | — | Meta-rules that teach how to write rules |
| [self-evolving-agent](https://github.com/miles990/self-evolving-agent) | — | 92% token reduction, North Star anchoring, PDCA loop |
| [wshobson/agents](https://github.com/wshobson/agents) | — | 72 single-purpose plugins, selective context loading |
| [DevSquad](https://github.com/joshidikshant/devsquad) | — | Hook-enforced delegation (docs fail after 25 sessions) |
| [Claude Squad](https://github.com/smtg-ai/claude-squad) | — | tmux + worktree agent isolation pattern |
| [Agents Squads](https://github.com/agents-squads/agents-squads) | — | SQUAD.md standard for team definition |
| [Aider](https://github.com/Aider-AI/aider) | — | Tree-sitter repo map, architect/editor split |
| [Skill Creator](https://github.com/anthropics/claude-plugins-official) | — | Eval/benchmark loop, description optimization |
| [Agent Skills Spec](https://agentskills.io) | — | Open standard for SKILL.md format |
