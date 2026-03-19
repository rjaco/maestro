# Ruflo Research Report

**Subject**: Ruflo (formerly Claude Flow) — https://github.com/ruvnet/ruflo
**Research Date**: 2026-03-18
**Researcher**: Maestro Research Agent

---

## Repository Stats

| Metric | Value |
|--------|-------|
| Stars | 21,600 |
| Forks | 2,400 |
| Commits | 5,987 |
| Open Issues | 412 |
| Current Version | 3.5.31 |
| npm packages | `ruflo`, `claude-flow` (both active) |
| Rebranded | Claude Flow → Ruflo at v3.5.0 (February 2026) |
| Development history | ~10 months alpha (55 iterations), stable since v3.5.0 |
| Wiki pages | 80 |

---

## What is Ruflo?

Ruflo is a production-ready, multi-agent AI orchestration framework that extends Claude Code via MCP. It turns Claude Code into a coordinated, self-learning swarm platform where 60+ specialized agents work together on complex software engineering tasks.

The platform installs as an MCP server:
```
claude mcp add ruflo -- npx -y ruflo@latest
```

It integrates natively into Claude Code's hook and tool system. It is also MCP-compatible with Claude Desktop, VS Code, Cursor, Windsurf, and ChatGPT (any MCP client).

The core value proposition: route every task to the cheapest handler that can complete it successfully, and learn from every execution to improve future routing.

Source: https://github.com/ruvnet/ruflo

---

## Architecture Overview

Requests flow through eight distinct layers:

```
User (Claude Code / CLI)
  └─ Entry Layer: MCP JSON-RPC + CLI (26 commands, 140+ subcommands)
       └─ Security Layer: AIDefence input validation + threat detection (<10ms)
            └─ Routing Layer: Q-Learning Router + MoE (8 experts) + Semantic Router
                 └─ Swarm Layer: UnifiedSwarmCoordinator (topology manager)
                      └─ Agent Layer: 60+ specialized agents (YAML-configured)
                           └─ Memory Layer: 4-tier backend (RuVector PG → AgentDB → SQLite → sql.js)
                                └─ RuVector Intelligence: SONA, EWC++, Flash Attention, HNSW
                                     └─ Learning Loop: RETRIEVE → JUDGE → DISTILL → CONSOLIDATE
```

The platform is a TypeScript monorepo under `@claude-flow/cli` with Rust/WASM modules for performance-critical paths. The root `ruflo` npm package is an umbrella delegating to the monorepo package.

---

## Competitor Matrix

| Feature | Ruflo | Maestro (Claude Code plugin, 89 skills) | Aider | Cursor | OpenHands |
|---------|-------|----------------------------------------|-------|--------|-----------|
| Multi-agent swarms | Yes (60+ agents, 6 topologies) | Yes (orchestrator + dispatched agents) | No | No | Limited |
| Cost-aware model routing | 3-tier WASM/Haiku/Opus automatic | No explicit tier routing | Model switch per session | No | No |
| Self-learning / Q-learning | Yes (Q-table + EWC++) | No | No | No | No |
| WASM kernels | Yes (Rust, policy/embeddings/proofs) | No | No | No | No |
| Background workers | Yes (12 autonomous workers) | No | No | No | No |
| Hook lifecycle system | Yes (17 hooks + 12 workers) | Yes (hooks system) | No | No | No |
| Persistent vector memory | Yes (HNSW, 4-tier backend) | No | No | No | No |
| Truth verification + BFT | Yes (cryptographic signing, auto-rollback) | No | No | No | No |
| Stream chaining (agent-to-agent pipe) | Yes (40-60% latency reduction) | No | No | No | No |
| CI/CD non-interactive mode | Yes | No | Yes | No | Yes |
| SWE-bench benchmarking CLI | Yes (85.2% claimed top mode) | No | No | No | Yes |
| GitHub automation agents | Yes (13 dedicated agents) | No | No | No | Limited |
| Pair programming system | Yes (real-time verification) | No | No | Yes (editor) | No |
| SPARC methodology | Yes (6 agents) | No | No | No | No |
| Benchmarking CLI | Yes (swarm-bench) | No | No | No | No |
| Security layer (AIDefence) | Yes (injection, TOCTOU, PII) | No | No | No | Sandboxed |
| ADR auto-generation | Yes (background worker) | No | No | No | No |
| Multi-LLM failover | Yes (Claude/GPT/Gemini/Ollama) | No (Claude only) | Yes | Yes | Yes |
| Total MCP tools | 215+ | 89 skills | N/A | N/A | N/A |

---

## Competitor Profile: Ruflo

**URL**: https://github.com/ruvnet/ruflo
**npm**: `ruflo` / `claude-flow`
**Author**: ruvnet (Reuven Cohen)

### Tech Stack
- Runtime: Node.js / TypeScript
- Performance kernels: Rust compiled to WASM via NAPI bindings:
  - `@ruvector/attention` (Flash Attention)
  - `@ruvector/router` (Q-Learning)
  - `@ruvector/sona` (SONA architecture)
  - `@ruvector/learning-wasm` (SIMD128 learning kernel)
- Vector DB: AgentDB v3 (HNSW indexing, ~61µs search latency), optional RuVector PostgreSQL (pgvector, 77 SQL functions)
- Memory fallback chain: RuVector PG → AgentDB → better-sqlite3 → sql.js (zero dependencies)
- MCP transport: stdio / HTTP / WebSocket

### Strengths
1. Self-learning architecture — Q-learning router improves with every task execution
2. WASM Agent Booster bypasses LLM entirely for mechanical code transforms ($0, <1ms)
3. 12 background workers run autonomously without user prompting
4. Rich documentation: 80-page wiki, CLAUDE.md, AGENTS.md, CHANGELOG.md
5. Truth Verification System with cryptographic signing and Byzantine fault tolerance
6. 4-tier memory fallback ensures zero-dependency operation
7. Claimed 85.2% SWE-bench solve rate in top swarm configuration
8. Active maintenance: 5,987 commits, near-daily releases in March 2025

### Weaknesses
1. Performance claims are self-reported and unverified by independent third parties
2. Recent history of security issues (obfuscated preinstall script removed in v3.5.3)
3. High complexity — 215+ MCP tools, 60+ agents, 80 wiki pages is a steep onboarding curve
4. Node.js/npm required; no shell-only or Python option
5. WASM NAPI modules degrade to pure JS; performance claims require native build environment
6. Linear stream chaining only (no branching yet); non-interactive mode required

### Differentiator
Self-learning Q-learning router combined with WASM Agent Booster that eliminates LLM calls for mechanical tasks. No other Claude Code plugin claims to persistently learn routing from task execution history.

---

## Feature Deep-Dives

### 1. Agent System — 60+ Agents, 16 Categories

**8 primary worker specializations** (Hive Mind base types):
Researcher, Coder, Analyst, Tester, Architect, Reviewer, Optimizer, Documenter

**Full category breakdown** (confirmed across wiki, CLAUDE.md, v3 issue):

| Category | Count | Examples |
|----------|-------|---------|
| Core Development | 5 | coder, reviewer, tester, planner, researcher |
| V3 Specialized | 10+ | queen-coordinator, hierarchical-coordinator, anti-drift-validator, token-optimizer, security-analyst, security-architect, memory-specialist, performance-engineer, system-architect |
| Swarm Coordination | 5 | hierarchical, mesh, adaptive, ring, star coordinators |
| Consensus Systems | 7 | byzantine, raft, gossip + CRDT mechanisms |
| GitHub Integration | 13 | PR management, code review, issue tracking, workflow automation, release orchestration |
| SPARC Framework | 6 | specification, pseudocode, architecture, refinement, completion, TDD agents |
| Performance | 5 | analysis, benchmarking, orchestration, optimization, profiling |
| Documentation | 2+ | auto-documenter, ADR generator |

Agent configuration is YAML-based with per-agent capability declarations, model preferences, and temperature settings. Architecture agents use Claude Opus at temperature 0.1–0.2; implementation agents use Sonnet at temperature 0.4.

**Team scaling guidance from docs**:
- Small feature: 1 coder + 1 tester + 1 reviewer
- Medium project: 1 coordinator + 2-3 coders + 1 architect + 1-2 testers + 1 reviewer
- Large project: multiple coordinators + 5+ coders + 2+ architects + 3+ testers + 2+ reviewers
- Enterprise: dynamic scaling 2–12 agents, queen-decides consensus

Source: https://github.com/ruvnet/ruflo/wiki/Agent-Usage-Guide, https://github.com/ruvnet/ruflo/blob/main/CLAUDE.md

---

### 2. Autonomous Operation Patterns

**Discipline enforced by CLAUDE.md**: "1 MESSAGE = ALL RELATED OPERATIONS." Every agent spawn, file operation, memory transaction, and terminal command must be batched in a single message. This prevents round-trip latency and reduces context overhead.

**12 Background Workers** (no user prompts required):

| Worker | Priority | Interval | Trigger Events |
|--------|----------|----------|----------------|
| audit | critical | 1h | always |
| optimize | high | 30m | always |
| ultralearn | normal | 1h | always |
| deepdive | normal | 2h | `complex-change` |
| map | normal | 4h | always |
| document | normal | on-event | `adr-update`, `api-change` |
| benchmark | normal | 4h | always |
| testgaps | normal | 2h | always |
| refactor | normal | 2h | always |
| predict | normal | 1h | always |
| consolidate | low | 2h | always |
| preload | low | 2h | always |

Workers operate on local state and embeddings — they consume no API tokens.

**17 Lifecycle Hooks**:
- Tool lifecycle (6): PreToolUse, PostToolUse, PreCompact (at 93% context), PostCompact, ToolError, ToolSuccess
- Intelligence routing (8): task model recommendation, agent booster availability, MoE gating signals
- Session management (4): SessionStart (restore state + auto-memory import), UserPromptSubmit (routing), SessionEnd (persist state), Stop (memory sync)
- The `transfer-store` hook enables cross-platform learning between Claude and Codex sessions

Source: https://deepwiki.com/ruvnet/ruflo, https://github.com/ruvnet/ruflo/blob/main/CLAUDE.md

---

### 3. Cost-Aware Model Routing (ADR-026)

The routing decision happens before any LLM call is made:

| Tier | Handler | Latency | Cost | Trigger |
|------|---------|---------|------|---------|
| 1 | Agent Booster (WASM/Rust) | <1ms | $0 | Mechanical transforms: var→const, type annotations, async-await conversion, error handling wrappers |
| 2 | Claude Haiku | ~500ms | $0.0002 | Complexity score <30%, simple Q&A, format conversion |
| 3 | Claude Sonnet / Opus + full swarm | 2–5s | $0.003–$0.015 | Complexity >30%, architecture design, security review |

**Hook-based routing signals**:
- `[AGENT_BOOSTER_AVAILABLE]` — WASM can handle this; LLM call skipped
- `[TASK_MODEL_RECOMMENDATION]` — suggests cheaper model; agent should downgrade
- PostToolUse outcomes update the Q-table for future routing decisions

**Token optimization stack** (additive, claimed):
- ReasoningBank retrieval (avoiding redundant LLM calls): -32%
- Agent Booster edits (WASM instead of LLM): -15%
- Caching (repeated patterns): -10%
- Batch optimization: -20%
- Total claimed: 30–50% token reduction

Claimed aggregate effect: "75% API cost savings," "250% subscription extension" (marketing language, not independently verified).

Source: https://deepwiki.com/ruvnet/ruflo, https://github.com/ruvnet/ruflo/blob/main/CLAUDE.md

---

### 4. Neural Q-Learning Routing

The `QLearningRouter` is a tabular Q-learning implementation with neural augmentation. It is not a deep RL system.

**Q-table structure**: keyed on (task_type, complexity_bucket, agent_type), storing (Q-value float, usage_count, last_updated timestamp).

**4-stage learning loop**:
1. RETRIEVE — HNSW pattern search (150x–12,500x faster than brute-force linear scan)
2. JUDGE — confidence scoring via trigram + Jaccard similarity
3. DISTILL — extract learnings through LoRA micro-fine-tuning (128x parameter compression via MicroLoRA)
4. CONSOLIDATE — EWC++ (Elastic Weight Consolidation++) preserves successful patterns and prevents catastrophic forgetting of previous routing decisions

**9 RL algorithms available**: Q-Learning (default router), SARSA, A2C, PPO, DQN, Decision Transformer, plus 3 others unspecified in docs. Q-learning is default; others are configurable per use case.

**Mixture of Experts (MoE)**: 8 expert networks with dynamic task-based gating. Gating function selects 1–3 experts per request based on task embedding similarity.

**SONA** (Self-Optimizing Neural Architecture): adapts routing weights in <0.05ms per decision. This is the online adaptation component that keeps routing current without full retraining cycles.

**Flash Attention**: `FlashAttentionOptimizer` selects backend at startup — NAPI native module → WASM fallback → pure JS fallback. Reported 2.49x–7.47x speedup on sequence processing.

Source: https://deepwiki.com/ruvnet/ruflo, https://github.com/ruvnet/ruflo/wiki/Neural-Networks

---

### 5. WASM Kernels

Four npm packages contain Rust-compiled WASM:

| Package | Function | Fallback |
|---------|----------|---------|
| `@ruvector/attention` | Flash Attention NAPI module | WASM → pure JS |
| `@ruvector/router` | Q-Learning routing with NAPI bindings | Pure JS |
| `@ruvector/sona` | Self-optimizing neural architecture | Pure JS |
| `@ruvector/learning-wasm` | Learning kernel with SIMD128 acceleration | Pure JS |

**Agent Booster** is the highest-value WASM application: AST-based mechanical code transforms (variable renaming, type annotation insertion, async/await conversion, error handling wrappers) in <1ms at $0. Claimed 352x faster than equivalent LLM call. (Note: this compares against calling a full model, not a quantized local model — the baseline matters.)

**WASM SIMD128**: matrix operations in the learning kernel. Claimed 50–70% faster training vs. non-SIMD.

**Cryptographic proof system**: every WASM operation generates a cryptographic witness. The RuVector Format (.rvf) stores embeddings, LoRA adapter deltas, GNN graph state, and a bootable Linux microkernel in one binary. A 5.5 KB WASM runtime executes .rvf queries anywhere from browser to bare metal.

**MutationGuard** in AgentDB v3 uses proof-based integrity verification for every write operation.

Source: https://github.com/ruvnet/ruvector, https://deepwiki.com/ruvnet/ruflo

---

### 6. Session Management and Context Handling

**Context Autopilot (ADR-051)**: at 93% context threshold, the `PreCompact` hook archives current state. After Claude's context compaction, `SessionStart` restores state from archive. This enables effectively infinite context via managed archiving.

**4-scope memory hierarchy**:
1. Project scope — shared across all agents in a project
2. Local scope — per-agent working memory
3. User scope — cross-project user preferences
4. Collaboration namespace — shared between Claude and Codex platforms (cross-platform learning)

**Pattern storage spec**:
- Confidence: float 0–1, decays over time
- Usage counters
- 384-dimensional embedding vectors
- Namespace segregation: "patterns" for routing, "learnings" for insights

**Persistence**: SQLite in WAL mode with crash safety. Cross-session state includes full swarm configuration, agent memory, pending tasks, and Q-table.

**AgentDB v3 — 8 specialized controllers**:

| Controller | Function |
|-----------|---------|
| HierarchicalMemory | Multi-scope isolation (project/local/user) |
| MemoryConsolidation | EWC++ pattern preservation |
| SemanticRouter | Intent-based routing via embeddings |
| GNNService | Graph neural network operations |
| RVFOptimizer | RuVector format optimization |
| MutationGuard | Proof-based write integrity verification |
| AttestationLog | Audit trail maintenance |
| GuardedVectorBackend | Protected vector storage with proofs |

Source: https://deepwiki.com/ruvnet/ruflo, https://github.com/ruvnet/ruflo/blob/main/CLAUDE.md

---

### 7. Swarm Topologies and Consensus

**6 swarm topologies**:

| Topology | Min Agents | Latency | Memory | Best Use |
|----------|-----------|---------|--------|----------|
| Hierarchical | 6 | 0.20s | 256 MB | Anti-drift coding, production |
| Mesh | 4 | 0.15s | 192 MB | Peer-to-peer, parallel work |
| Ring | 3 | 0.12s | 128 MB | Sequential pipelines |
| Star | 5 | 0.14s | 180 MB | Hub-and-spoke distribution |
| Hybrid | 7 | 0.18s | 320 MB | Mixed workloads |
| Adaptive | 2 | variable | dynamic | Unknown complexity |

**4 consensus protocols**:
- Raft: leader-based, 50%+ majority required
- Byzantine: 2/3 majority (handles malicious/failed nodes)
- Gossip: eventually consistent for large swarms
- CRDT: conflict-free replicated data, no coordination overhead

**Queen types**: Strategic Queen (long-term planning), Tactical Queen (resource allocation), Adaptive Queen (dynamic load rebalancing). Conflict resolution defaults to `queen-decides` with 0.7 consensus threshold.

Source: https://github.com/ruvnet/ruflo/wiki/Hive-Mind-Intelligence, https://deepwiki.com/ruvnet/ruflo

---

### 8. Stream Chaining (Agent-to-Agent JSON Piping)

Uses Claude Code's `--output-format stream-json` and `--input-format stream-json` flags. No intermediate files. Dependencies declared in workflow JSON activate automatic chaining.

**Performance vs. file-based handoffs**:
- Latency: 40–60% reduction
- Context preservation: 100% vs. 60–70% for file-based
- Memory: 2.3x less usage
- End-to-end speed: 1.8x faster
- Error rate: 0.8% vs. 3.2%

**Stream message types (NDJSON)**: `init`, `message`, `tool_use`, `tool_result`, `result`.

**Current limitations**: non-interactive mode only; linear chains only (no branching); chains from last dependency when multiple exist; requires clean JSON compliance.

Source: https://github.com/ruvnet/ruflo/wiki/Stream-Chaining

---

### 9. Truth Verification System

Mandatory verification before any agent claim or task completion is accepted. Architecture: Verification Engine + Truth Scorer (0.0–1.0 weighted) + Rollback Manager.

**Thresholds**:
- Strict (production): 95%, auto-rollback on failure, consensus required
- Moderate (development): 85%, no auto-rollback, consensus required
- Development (prototyping): 75%, optional consensus

**Scoring weights for coder agents**: compilation 35%, testing 25%, linting 20%, type-checking 20%.

**Security properties**: cryptographic signing of all results, Byzantine fault tolerance (2/3+ consensus), automatic agent quarantine for malicious behavior, audit trail persisted to `.swarm/verification-memory.json`.

**Performance targets**: truth accuracy >95%, integration success >90%, rollback frequency <5%, human intervention <10%.

Source: https://github.com/ruvnet/ruflo/wiki/Truth-Verification-System

---

### 10. MCP Tools — 87 Published, 215+ Internal

The wiki documents 87 MCP tools. The v3.5.0 release notes cite 215 MCP tools total (includes internal registration). Organized in 9 categories:

| Category | Count | Capabilities |
|----------|-------|-------------|
| Swarm Management | 16 | Agent spawning, topology optimization, load balancing |
| Neural & AI | 15 | Pattern training, model management, inference, transfer learning, explainability |
| Memory & Persistence | 10 | Store/retrieve, namespacing, TTL, backup/restore |
| Performance & Analytics | 10 | Metrics, bottleneck detection, benchmarking, trend analysis |
| GitHub Integration | 6 | Repo analysis, PR management, issue tracking, workflow automation |
| Dynamic Agent Architecture | 6 | Agent creation, capability matching, resource allocation, consensus |
| Workflow & Automation | 8 | Pipeline creation, scheduling, event triggers, templates |
| System Utilities | 16 | Configuration, security scanning, diagnostics, state snapshots |

Exposed via `mcp__claude-flow__` namespace in Claude Code.

Source: https://github.com/ruvnet/ruflo/wiki/MCP-Tools

---

### 11. GitHub Integration (13 Agents)

Dedicated GitHub agents covering: PR management (open, review, merge), issue tracking and triage, code review automation, GitHub Actions workflow automation, release orchestration, multi-repository coordination. Git hooks trigger automatic checkpoint releases.

Source: CLAUDE.md, wiki GitHub Integration page

---

### 12. SPARC Methodology

Structured development lifecycle: Specification → Pseudocode → Architecture → Refinement → Completion. 6 agents, one per phase. Integrates with Truth Verification for phase-gate compliance.

**SWE-bench results (self-reported)**:
- `swarm-optimization-mesh-8agents`: 85.2% (420s avg)
- `hive-mind-8workers`: 82.7% (380s avg)
- `sparc-coder-5agents`: 78.3% (445s avg)
- `swarm-development-hierarchical-8agents`: 76.9% (390s avg)
- `sparc-tdd-5agents`: 74.1% (520s avg)

Note: these results are generated by Ruflo's own `swarm-bench` CLI, not submitted to the official SWE-bench leaderboard. Independent verification not found.

Source: https://github.com/ruvnet/ruflo/wiki/Benchmark-System

---

### 13. Pair Programming System

Real-time AI-human collaborative sessions. Verification-first: every change validated against truth thresholds before acceptance. Interactive commands: `/verify`, `/test`, `/status`, `/metrics`, `/auto`, `/switch`, `/commit`. 60s cooldown between auto-checks. Sessions generate verification data feeding the training pipeline. VSCode plugin and git hook integration supported.

Source: https://github.com/ruvnet/ruflo/wiki/Pair-Programming-System

---

### 14. Multi-LLM Support

Claude, GPT-4, Gemini, Cohere, Ollama (local models) with automatic failover. Model selection is YAML-configured per agent type and enforced by the routing tier. This enables Ruflo to operate without an Anthropic subscription, unlike Maestro.

Source: https://github.com/ruvnet/ruflo (main README)

---

### 15. Security: AIDefence

Built-in security at the entry layer:
- Prompt injection blocking (<10ms detection)
- Input validation via Zod schemas at all system boundaries
- Path traversal pattern detection
- Command injection via allowlisted execution
- PII automatic scanning and redaction
- CVE monitoring with active vulnerability patching
- Multi-agent consensus for security decisions

Historical note: v3.5.3 removed an obfuscated preinstall script (supply chain risk). This was present through multiple alpha versions before discovery.

Source: https://deepwiki.com/ruvnet/ruflo, v3.5.14 release notes

---

## Technical Patterns Observed

1. **Graceful degradation everywhere**: NAPI → WASM → pure JS for every performance module. Zero-dependency operation is a design requirement, not an afterthought. The sql.js fallback means Ruflo works in any environment.

2. **Hook-as-protocol**: All system integrations go through stdin/stdout JSON hooks. This creates a uniform, testable interface for routing, memory, verification, and learning.

3. **Memory as infrastructure**: Vector memory is not a feature — it is the primary communication medium between agents and across sessions. The HNSW index and Q-table only have value with persistent memory.

4. **Cryptographic provenance**: The proof/witness chain in WASM kernels and MutationGuard indicates a design goal of auditable, verifiable AI operations. This is unusual in open-source AI tooling and likely targeting enterprise compliance use cases.

5. **ADR-driven architecture**: The codebase uses numbered ADRs (ADR-001 through ADR-061+ documented) as authoritative implementation references. A background worker auto-generates ADRs when architectural changes are detected in the codebase.

6. **Spec-first anti-drift**: The hierarchical swarm topology plus anti-drift-validator agent is explicitly designed to prevent implementations from diverging from specifications. The Truth Verification System enforces this at the output level.

---

## Anti-Patterns Observed

1. **Obfuscated preinstall script**: present in multiple alpha versions, removed in v3.5.3. The claimed "zero production vulnerabilities" conflicts with this history.

2. **Self-reported benchmarks**: all SWE-bench results use `swarm-bench` CLI against the project's own configurations. Not submitted to official SWE-bench leaderboard. Treat all performance numbers as directional, not verified.

3. **Benchmark baseline ambiguity**: "352x faster than LLM" compares WASM Agent Booster against calling a full cloud model. The baseline is not a fair comparison for all use cases.

4. **Documentation lag**: Several wiki pages returned loading errors during research. Some pages still reference `npx claude-flow@alpha`, suggesting content not fully updated for stable release.

5. **Agent count inconsistency**: "60+ agents," "64 agents," and "47 agents" appear across different pages and issue threads. No single canonical count is documented.

---

## SEO / Discoverability

- GitHub repo title is heavily keyword-optimized for AI orchestration search terms
- DeepWiki has a comprehensive indexed analysis at https://deepwiki.com/ruvnet/ruflo
- Third-party coverage: mlhive.com, aiany.app, openclawapi.org
- X/Grok thread discussing Agent Booster routing signals organic discovery
- No independent peer-reviewed benchmarks found as of research date

---

## Features Ruflo Has That Maestro Does Not

Concrete capabilities where Ruflo has implemented something Maestro currently lacks:

| Feature | Ruflo Implementation | Maestro Gap |
|---------|---------------------|-------------|
| **Self-learning Q-table router** | Tabular Q-learning updates after every task; routes future similar tasks to historically best agents | Maestro skill dispatch is stateless — no execution history is recorded for routing decisions |
| **3-tier cost routing** | WASM (<1ms, $0) → Haiku → Opus selected automatically by complexity score | Maestro uses Claude for every request; no WASM bypass layer |
| **12 background workers** | Autonomous daemons run security audits, codebase mapping, memory consolidation on schedules without user prompts | Maestro has no autonomous background operation |
| **Truth verification system** | Cryptographic signing + BFT consensus + auto-rollback on verification failure | Maestro has no formal output verification or rollback mechanism |
| **Persistent vector memory with HNSW** | 384-dimensional embeddings, HNSW indexing, cross-session pattern retrieval at ~61µs | Maestro has no persistent vector memory |
| **Stream chaining** | Agent-to-agent NDJSON piping with 40-60% latency reduction vs. file-based handoffs | Maestro dispatches agents but does not pipe outputs directly between them |
| **EWC++ catastrophic forgetting prevention** | Elastic weight consolidation preserves successful routing patterns across learning cycles | Not applicable without a persistent learning loop |
| **WASM Agent Booster** | Bypasses LLM for mechanical transforms (var→const, type annotation, async-await) using AST analysis | All transforms go through Claude API calls |
| **Multi-LLM failover** | Claude + GPT-4 + Gemini + Ollama with automatic failover | Claude Code only |
| **13 dedicated GitHub agents** | PR management, issue triage, release orchestration, multi-repo coordination as first-class agents | Maestro has no dedicated GitHub agent specializations |
| **Pair programming system** | Real-time AI-human collaboration with verification-first approach and interactive session commands | Maestro operates in request-response mode only |
| **ADR auto-generation** | Background worker detects architectural changes and auto-generates ADRs | No ADR automation |
| **Non-interactive / CI mode** | Full headless operation for CI/CD pipelines | Maestro requires an interactive Claude Code session |
| **Byzantine fault tolerance** | 2/3 consensus for multi-agent decisions; automatic agent quarantine | No consensus mechanism |
| **SWE-bench benchmarking CLI** | `swarm-bench` CLI for reproducible performance testing across swarm configurations | No benchmarking capability |
| **6 swarm topology options** | Hierarchical / mesh / ring / star / hybrid / adaptive, each with different latency/memory tradeoffs | Maestro uses flat skill dispatch |
| **Context autopilot (ADR-051)** | Automated context archiving at 93% threshold; full state restore after compaction | Manual context management |
| **Cryptographic proof chain** | Every WASM operation generates a verifiable proof; MutationGuard on all writes | No operation provenance |
| **SPARC methodology** | Structured 6-phase development lifecycle with phase-gate verification | No built-in development methodology |
| **AIDefence security layer** | Prompt injection blocking, PII scanning, command injection prevention at entry | No dedicated security layer |

---

## Sources

- https://github.com/ruvnet/ruflo
- https://github.com/ruvnet/ruflo/blob/main/README.md
- https://github.com/ruvnet/ruflo/blob/main/CLAUDE.md
- https://github.com/ruvnet/ruflo/wiki
- https://github.com/ruvnet/ruflo/wiki/Hive-Mind-Intelligence
- https://github.com/ruvnet/ruflo/wiki/Neural-Networks
- https://github.com/ruvnet/ruflo/wiki/Agent-Usage-Guide
- https://github.com/ruvnet/ruflo/wiki/Workflow-Orchestration
- https://github.com/ruvnet/ruflo/wiki/MCP-Tools
- https://github.com/ruvnet/ruflo/wiki/Stream-Chaining
- https://github.com/ruvnet/ruflo/wiki/Truth-Verification-System
- https://github.com/ruvnet/ruflo/wiki/Pair-Programming-System
- https://github.com/ruvnet/ruflo/wiki/Benchmark-System
- https://github.com/ruvnet/ruflo/issues/1240 (v3.5.0 release overview)
- https://github.com/ruvnet/ruflo/issues/945 (v3 rebuild details)
- https://github.com/ruvnet/ruflo/releases
- https://deepwiki.com/ruvnet/ruflo
- https://mlhive.com/2026/03/architecting-autonomous-multi-agent-systems-using-ruflo
- https://aiany.app/item/ruflo-ruflo-enterprise-ai-orchestration-platform
