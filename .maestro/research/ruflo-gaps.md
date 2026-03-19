# Ruflo Research — Remaining Feature Gaps for Maestro

**Research Date**: 2026-03-18
**Researcher**: Maestro Research Agent
**Source Repo**: https://github.com/ruvnet/ruflo (21.6k stars, last commit 2026-03-19)
**Prior research file**: `.maestro/research/ruflo.md` (covered initial feature comparison)

This document focuses exclusively on Ruflo patterns and features that Maestro has NOT yet adopted,
after excluding the six categories the prompt confirms Maestro has already implemented:

- 6 swarm topologies + 3-tier cost routing
- Pair programming + 6 background autonomous workers
- Multi-LLM failover + 4-phase learning loop
- Stream chaining + agent team coordination
- Context autopilot + CI mode
- ADR auto-generation + truth verification

---

## Competitor Matrix (Focused on Remaining Gaps)

| Feature Area | Ruflo Has | Maestro Has | Gap Status |
|---|---|---|---|
| SPARC development methodology | Yes (5-phase, 6 agents) | No | OPEN |
| Claims / task ownership protocol | Yes (7-tier permissions, human-agent handoff) | No | OPEN |
| Multi-repository swarm coordination | Yes (org-wide automation, webhook mesh) | No | OPEN |
| Production validator (mock-detection gate) | Yes (blocks deployment on mock code) | No | OPEN |
| London School TDD swarm | Yes (outside-in, shared mock contracts) | No | OPEN |
| Scout/Explorer agent pattern | Yes (recon-first, report-before-modify) | No | OPEN |
| GitHub Project Board sync | Yes (bidirectional, auto-transitions) | Partial (Kanban skill, no GitHub Projects) | PARTIAL |
| Dedicated code review swarm (4 parallel agents) | Yes (security/perf/style/arch in parallel) | Partial (multi-review is 3-perspective) | PARTIAL |
| Release swarm (semantic versioning + staged rollout) | Yes (staged rollout, multi-target publish) | No | OPEN |
| Agentic payments (mandate-based auth) | Yes (Ed25519 + BFT consensus) | No | OPEN |
| E2B sandbox execution | Yes (isolated containerized runs) | No | OPEN |
| Adaptive topology switching (auto-reconfigure) | Yes (threshold-triggered, 4-phase migration) | No | OPEN |
| PageRank-based agent/code criticality analysis | Yes | No | OPEN |
| Gossip protocol coordination | Yes (push/pull/hybrid with Merkle anti-entropy) | No | OPEN |
| CRDT-based distributed state | Yes (G-Counter, OR-Set, RGA sequence) | No | OPEN |
| Quorum management (weighted, capability-based) | Yes | No | OPEN |
| Work-stealing load balancer | Yes (EDF + CFS + multi-level feedback) | No | OPEN |
| Federated neural training | Yes (data stays local, proof-of-learning) | No | OPEN |
| 3-tier episodic/semantic/procedural memory | Yes (session/long-term/pattern layers) | Partial (dual-sector with salience decay) | PARTIAL |
| Benchmark suite with CUSUM regression detection | Yes (statistical + ML anomaly detection) | Partial (benchmark skill, no CUSUM) | PARTIAL |
| SLA monitoring with WebSocket dashboards | Yes (99.9% availability, 1s update interval) | No | OPEN |
| Agentic Jujutsu VCS (lock-free concurrent commits) | Yes (23x vs Git, 87% auto-conflict-resolve) | No | OPEN |
| Domain-specific plugins (healthcare/legal/finance) | Yes (6 vertical plugins) | No | OPEN |
| Quantum-resistant cryptography | Yes (SHA3-512, HQC-128) | No | OPEN |
| Transfer learning across domains | Yes (multi-task + curriculum + active learning) | No | OPEN |

---

## Competitor Profile

**URL**: https://github.com/ruvnet/ruflo
**Tech stack**: TypeScript monorepo, Rust/WASM kernels, AgentDB (HNSW), SQLite WAL fallback
**Key differentiator**: Self-learning Q-table router + WASM Agent Booster that bypasses LLM for mechanical transforms

**Ruflo strengths Maestro does not match**:
- Lock-free concurrent agent commits (Agentic Jujutsu vs Git)
- E2B sandbox isolation for safe code execution
- Production validator that blocks deployment if mock implementations are detected
- Mandate-based agentic payment authorization (cryptographically signed spending caps)
- Domain-specific vertical plugins (healthcare-clinical, financial-risk, legal-contracts)

**Ruflo weaknesses** (things Maestro does better):
- Steep onboarding (215+ MCP tools, 80 wiki pages)
- Self-reported benchmarks not submitted to official SWE-bench leaderboard
- Historical supply-chain security incident (obfuscated preinstall script, removed v3.5.3)
- No equivalent to Maestro's second-brain (Obsidian/Notion) integration
- No content/marketing pipeline (Maestro's knowledge work skills have no parallel in Ruflo)
- No config profile switching or remote control (Telegram/Discord)

---

## Technical Patterns

### Pattern 1: SPARC Methodology (Spec-First Phased Development)

Ruflo enforces a five-phase development lifecycle as a first-class agent workflow:
Specification -> Pseudocode -> Architecture -> Refinement -> Completion.
Each phase has a dedicated agent. Phase gates are enforced by the Truth Verification System —
an agent cannot proceed to "Architecture" until the "Pseudocode" phase produces a passing
verification score (default threshold: 0.95).

The methodology is skipped for simple tasks (bug fixes, config changes) to prevent over-engineering.
The decision to invoke SPARC vs. standard dev-loop is made by a classifier similar to Maestro's.

Source: `.agents/skills/sparc-methodology/SKILL.md`, `.agents/skills/agent-sparc-coordinator/SKILL.md`

**Maestro gap**: No formalized multi-phase pre-implementation protocol with phase-gate verification.
Maestro's `decompose` skill breaks features into stories but does not enforce specification and
pseudocode phases before implementation begins.

---

### Pattern 2: Claims and Task Ownership Protocol

Ruflo implements a formal claims authorization framework governing which agent (or human) owns
which task at any point. Seven permission tiers: read, write, execute, spawn, memory, network,
admin — each scoped to specific resource patterns (e.g., write access limited to `/src/**`).

Four security tiers aggregate permissions: minimal (read-only), standard (read/write/execute),
elevated (adds spawn/memory), admin (all). Human operators grant claims at task start and revoke
on completion. Audit trail is maintained per claim.

The pattern enables "stealable tasks": if an agent is overloaded, its claim on a low-priority
task can be reassigned to an idle agent via the load balancer without human intervention.

Source: `.agents/skills/claims/SKILL.md`, README claims section

**Maestro gap**: No formal task ownership semantics. Maestro's delegation skill dispatches agents
but does not model ownership, revocation, or least-privilege access control for task execution.

---

### Pattern 3: Multi-Repository Swarm Coordination

Ruflo deploys agents across multiple GitHub repositories simultaneously, treating the organization's
codebase graph as the unit of work. Coordination mechanisms:

- Webhook-based event propagation between repos
- Eventual consistency (5-minute max lag) for routine updates; Raft consensus for security patches
- Shared Redis-backed memory so frontend-repo agents can inform backend-repo decisions
- Dependency discovery via `package.json` traversal to identify cross-repo impact before changes
- Role-based agent assignment (frontend repos get UI specialists; backend repos get architects)

A single multi-repo swarm command can: update a shared library, propagate version bumps to all
dependents, run compatibility tests per-repo, and open PRs across all affected projects.

Source: `.agents/skills/agent-multi-repo-swarm/SKILL.md`, `.agents/skills/github-multi-repo/SKILL.md`

**Maestro gap**: Maestro's workspace skill isolates sessions by project. There is no mechanism
to coordinate agents across multiple repos in a single workflow.

---

### Pattern 4: Production Validator (Mock-Detection Gate)

Before any deployment, Ruflo's production validator scans the codebase for placeholders that
must not exist in production:

- Patterns matched: `mock/fake/stub` prefixes, TODO/FIXME comments, unimplemented error throws,
  in-memory databases where real connections are expected
- Integration checks: real database connections, live API credentials, actual Redis/SMTP servers
- Performance gates: concurrent request handling, sustained load at production dataset sizes,
  latency at p95 with 95% success rate minimum

Deployment is blocked if any check fails. The validator runs as a pre-deployment hook and a
post-deployment verification step. Git-based rollback executes in under 1 second if post-deploy
checks fail.

Source: `.agents/skills/agent-production-validator/SKILL.md`

**Maestro gap**: No deployment gate that specifically detects mock/stub implementations and
validates integration against real (non-test) infrastructure. Maestro's `qa-reviewer` checks
code quality but not production-readiness in this operational sense.

---

### Pattern 5: London School TDD Swarm

Ruflo's TDD swarm implements the London (mockist) school of test-driven development across
multiple coordinated agents:

- Outside-in flow: acceptance tests -> integration tests -> unit tests
  (user-facing behavior drives implementation direction)
- Shared mock contracts: all agents agree on mock definitions before implementation begins;
  contracts are versioned and shared across the swarm
- Cross-agent contract evolution: when requirements change, mock updates propagate to dependent
  agents automatically
- Bidirectional feedback: unit test agents report interaction patterns to integration agents;
  architecture agents receive data about emerging collaboration requirements

This differs from standard TDD by treating the mock contract as a coordination artifact, not
just a test detail.

Source: `.agents/skills/agent-tdd-london-swarm/SKILL.md`

**Maestro gap**: Maestro's `test-gen` skill generates tests independently within each story's
scope. There is no coordinated outside-in TDD with shared mock contracts between agents.

---

### Pattern 6: Scout/Explorer Agent Pattern

Ruflo's scout-explorer is a reconnaissance-only agent that maps unknown territory before
any modification agents are dispatched. Three exploration strategies:

1. Breadth-first survey: rapid landscape scan to identify high-level patterns
2. Depth-first investigation: focused analysis of specific regions, documenting hidden issues
3. Continuous patrol: ongoing monitoring to detect changes and anomalies over time

Scouts produce intelligence reports (architecture, dependencies, performance bottlenecks,
security threats, optimization opportunities) and store findings immediately to shared memory.
They do not modify files or make decisions — that separation is enforced by the skill definition.

Source: `.agents/skills/agent-scout-explorer/SKILL.md`

**Maestro gap**: Maestro's `project-dna` skill discovers stack and conventions but is not
a continuously-dispatchable scout that runs ahead of execution agents. No recon-only role
is formally defined.

---

### Pattern 7: Adaptive Topology Switching (Live Reconfiguration)

The Ruflo adaptive coordinator monitors swarm performance continuously and switches topology
when metrics degrade more than 20% below historical baselines. Reconfiguration has four phases:

1. Baseline analysis
2. Migration planning (candidate topologies scored on latency, throughput, fault tolerance,
   scalability using genetic algorithms and simulated annealing)
3. Incremental transition (not a hard cutover)
4. Validation with automatic rollback if error rates exceed 25% or agent failures exceed 30%

Predictive scaling uses ML models that forecast resource needs 4 hours ahead. The system
generates optimal routing tables and adapts communication protocols (TCP, UDP, gRPC, MQTT)
to match agent pair requirements.

Source: `.agents/skills/agent-adaptive-coordinator/SKILL.md`, `.agents/skills/agent-topology-optimizer/SKILL.md`

**Maestro gap**: Maestro selects a squad configuration at session start and does not dynamically
restructure agent relationships based on observed performance during execution.

---

### Pattern 8: PageRank-Based Agent Criticality Analysis

Ruflo applies PageRank to agent communication graphs and code dependency graphs to identify
structural hubs. In agent networks, higher damping (0.9 vs standard 0.85) reflects ongoing
interdependencies.

Results inform:
- Topology redesign (remove routing through low-PageRank intermediaries)
- Resource concentration (more compute to high-PageRank hub agents)
- Fault planning (redundancy prioritized for critical agents identified by rank)
- Bottleneck resolution (restructure connections away from low-ranked chokepoints)

Applied to codebases: functions and modules ranked by dependency centrality produce a
criticality map guiding where to focus review and testing effort.

Source: `.agents/skills/agent-pagerank-analyzer/SKILL.md`

**Maestro gap**: No graph-theoretic criticality analysis of agent networks or code dependency graphs.

---

### Pattern 9: Work-Stealing Load Balancer with Advanced Scheduling

Ruflo's load balancer implements scheduling algorithms beyond simple round-robin:

- Work-stealing: idle agents proactively steal from overloaded peers; global fallback queue
  when local queues are empty
- Earliest Deadline First (EDF): tasks sorted by deadline urgency; Liu & Layland admission
  control prevents overcommitment (total utilization cannot exceed 100%)
- Completely Fair Scheduler (CFS): red-black tree + virtual runtime tracking, similar to
  Linux kernel scheduling
- Weighted Fair Queuing (WFQ): tasks scheduled by calculated finish time with per-agent weights
- Multi-Level Feedback Queuing: critical 40%, high 30%, normal 20%, low 10%;
  age-based priority boosting prevents starvation
- Multi-objective genetic optimization: minimize latency + maximize utilization + balance load simultaneously

Source: `.agents/skills/agent-load-balancer/SKILL.md`

**Maestro gap**: Maestro's delegation skill assigns tasks at session start. There is no mechanism
for idle agents to steal work from overloaded ones or for priorities to shift based on observed
execution times.

---

### Pattern 10: E2B Sandbox Execution

Ruflo integrates with E2B (cloud sandbox provider) to run agent-generated code in isolated
containerized environments. Lifecycle:

1. Create: provision a named sandbox with a language template (Node.js, Python, React, etc.)
2. Execute: run code within sandbox boundary with captured stdout/stderr
3. File management: controlled upload/download within sandbox scope
4. Cleanup: explicit stop and delete calls terminate the environment

Sensitive credentials are passed via environment variables, not embedded in code. Timeouts and
resource limits are configured per execution. Multiple sandbox templates are pre-configured.

Source: `.agents/skills/agent-sandbox/SKILL.md`, `v3/plugins/flow-nexus-neural/`

**Maestro gap**: All Maestro agent execution happens in the local project context. There is
no sandboxed execution path for agent-generated code.

---

### Pattern 11: Agentic Payments (Mandate-Based Authorization)

Ruflo implements a framework for agents to autonomously execute financial transactions within
pre-approved constraints:

- Active Mandates: spending caps, time windows, and merchant allowlists define the authorization envelope
- Ed25519 cryptographic signing: every transaction signed; tampering is detectable
- Multi-agent BFT consensus for high-value transactions: a single compromised agent cannot
  authorize large spending
- Real-time mandate revocation
- Complete audit trail for compliance

Use cases: e-commerce shopping agents with weekly budgets, robo-advisor trade execution,
enterprise procurement requiring multi-agent approval for large purchases.

Source: `.agents/skills/agent-agentic-payments/SKILL.md`

**Maestro gap**: No model for agents to authorize financial or resource expenditures. This is
a distinct capability class (autonomous commerce) with no current parallel in Maestro.

---

### Pattern 12: Release Swarm (Staged Deployment Orchestration)

Ruflo's release swarm goes beyond changelog generation to coordinate full deployment pipelines:

- Semantic versioning intelligence: analyzes commits/PRs to determine correct version bump;
  detects BREAKING keywords for major version bumps
- Contributor attribution in generated changelogs
- Progressive rollout: monitors error rates and latency at each stage; halts if thresholds exceeded
- Multi-target parallel publishing: npm, Docker, GitHub Releases simultaneously
- Pre-release validation: dependency compatibility, security scan, API contract verification
- Automated rollback with grace periods (avoids knee-jerk reversion on transient errors)

Source: `.agents/skills/agent-release-swarm/SKILL.md`, `.agents/skills/github-release-management/SKILL.md`

**Maestro gap**: Maestro's `ship` skill creates PRs and does final quality gates, but does not
manage post-merge deployment stages or automatic rollback based on production metrics.

---

### Pattern 13: Federated Neural Training

Ruflo supports federated learning for model training across distributed nodes:

- Data remains on local nodes (privacy-preserving)
- proof-of-learning consensus validates training contributions
- Byzantine fault tolerance for distributed training validation
- Decentralized Autonomous Agents (DAA) with node-level autonomy (0-1 scale)
- Five learning modes: real-time (<0.5ms), balanced (<18ms), research (<100ms),
  edge (<1ms), batch (<50ms)

Source: `.agents/skills/flow-nexus-neural/SKILL.md`, `v3/plugins/neural-coordination/`

**Maestro gap**: Maestro's learning is session-local (retrospective, self-correct skills).
There is no distributed training or knowledge sharing across multiple deployment instances.

---

### Pattern 14: Three-Tier Episodic/Semantic/Procedural Memory

Ruflo structures agent memory across three cognitively distinct layers:

1. Episodic (session memory): recent messages, current session context, last N interactions,
   ordered chronologically
2. Semantic (long-term facts): user preferences, domain facts, structured by category/key/value,
   indexed by meaning rather than time
3. Procedural (pattern learning): trigger-response pairs with success metrics, learned from
   successful interactions, executable strategies that feed the Q-learning router

Each layer has different retrieval semantics and different persistence horizons. The procedural
layer feeds directly into routing decisions (patterns with high success scores get higher
routing weights).

Source: `.agents/skills/agentdb-memory-patterns/SKILL.md`

**Maestro has**: dual-sector memory with confidence scoring and salience decay. This is ahead
of most tools, but conflates episodic and semantic memory into one store. There is no separate
procedural layer that explicitly feeds routing decisions.

---

### Pattern 15: SLA Monitoring with Real-Time Anomaly Detection

Ruflo's performance monitor enforces SLA contracts and broadcasts metrics:

- SLA thresholds: availability (default 99.9%), response time (default 1000ms), throughput,
  error rate, recovery time
- Alert severity levels: warning (80%), critical (90%), breach
- Four-model ensemble anomaly detection: statistical (3-sigma), machine learning,
  time-series LSTM, behavioral modeling
- WebSocket subscriptions with 1-second update intervals
- Circular buffer history for trend analysis
- Multi-layer bottleneck analysis across CPU, memory, I/O, network, coordination, task queue

Source: `.agents/skills/agent-performance-monitor/SKILL.md`

**Maestro gap**: Maestro's `watch` skill monitors tests and types via CronCreate, but does not
model SLA contracts or use statistical anomaly detection on agent/system performance.

---

### Pattern 16: Benchmark Suite with Statistical Regression Detection

Ruflo's benchmark suite adds statistical rigor beyond basic timing:

- p50/p90/p95/p99/max latency distributions (not just averages)
- CUSUM (Cumulative Sum) algorithm for change-point detection (configurable sensitivity,
  default 0.95 confidence)
- ML anomaly detector trained on historical benchmark data, assigns anomaly scores to current runs
- Warmup (30s) and cooldown periods to isolate stable measurements
- SLA violation reports generated before production deployment

Source: `.agents/skills/agent-benchmark-suite/SKILL.md`

**Maestro has**: a `benchmark` skill, but it lacks CUSUM change-point detection and per-percentile
latency tracking. Regression detection is not statistical.

---

### Pattern 17: Agentic Jujutsu (Lock-Free Concurrent VCS)

Ruflo introduces a version control approach designed for concurrent AI agent commits:

- No locks or synchronization barriers; agents commit independently at 350 ops/s vs Git's 15 ops/s
  (23x claimed)
- 87% automatic conflict resolution rate vs Git's 30-40%
- ReasoningBank integration: learns which merge strategies succeed and recommends them for
  similar future conflicts
- SHA3-512 fingerprinting + HQC-128 post-quantum encryption for commit integrity
- Integrity verification in under 1ms

Source: `.agents/skills/agentic-jujutsu/SKILL.md`

**Maestro gap**: Maestro's `git-craft` and `speculative` skills use standard Git and worktrees
to manage isolation, which serializes agent contributions. No lock-free concurrent commit model exists.

Note: the 23x and 87% figures are self-reported and unverified.

---

### Pattern 18: Gossip Protocol Coordination

Ruflo implements gossip protocols for large-scale swarms where centralized coordination creates
bottlenecks:

- Push gossip: nodes proactively broadcast updates to randomly selected peers
- Pull gossip: nodes request missing state from peers
- Hybrid push-pull: balanced convergence speed
- Merkle tree comparison for efficient difference detection (minimal bandwidth)
- Vector clocks for causal tracking of concurrent updates
- Topology-aware membership management (node join/failure without a coordinator)

Source: `.agents/skills/agent-gossip-coordinator/SKILL.md`

**Maestro gap**: Maestro's agent coordination is centralized through the orchestrator. There is
no peer-to-peer propagation model for eventually-consistent coordination.

---

### Pattern 19: CRDT-Based Distributed State

Ruflo uses Conflict-Free Replicated Data Types for state that multiple agents update concurrently
without coordination overhead:

- G-Counter: distributed increment, merge via max-per-node
- OR-Set: add/remove with tagged uniqueness; concurrent operations do not conflict
- RGA sequence: concurrent insertions ordered by causal vertex identifiers
- Causal tracker: buffers operations until dependencies satisfied before executing
- Composable: CRDT types combine into complex structures

The key property: merge operations are commutative and idempotent — agents converge to identical
state regardless of message order.

Source: `.agents/skills/agent-crdt-synchronizer/SKILL.md`

**Maestro gap**: Maestro agents read/write to shared markdown files. Concurrent writes produce
conflicts that require manual resolution. There is no conflict-free concurrent state model.

---

### Pattern 20: Domain-Specific Vertical Plugins

Ruflo ships six domain-specific plugin packages with specialized agents for regulated industries:

- `healthcare-clinical`: clinical workflow agents, HIPAA-aware processing
- `financial-risk`: risk modeling agents, compliance checking
- `legal-contracts`: contract analysis with DAG-based document structure
- `code-intelligence`: deep code analysis beyond standard review
- `test-intelligence`: coverage intelligence, learning-based test gap detection
- `perf-optimizer`: FPGA bridge, sparse computation optimization

Each plugin follows the same bridge architecture (TypeScript + WASM) and integrates with AgentDB
for domain-specific memory namespaces.

Source: `v3/plugins/` directory tree (verified file listing via gh API)

**Maestro gap**: Maestro's specialist profiles (healthcare, legal, etc.) are instruction sets for
Claude, not packaged agent+memory+tool bundles optimized for a specific domain's regulatory
and workflow requirements.

---

## Anti-Patterns Observed

1. **Benchmark self-reference**: All performance numbers (23x faster VCS, 87% conflict resolution,
   350 ops/s, 85.2% SWE-bench) are self-reported using Ruflo's own `swarm-bench` CLI. No submissions
   to official external benchmarks found as of 2026-03-18.

2. **Complexity barrier**: 215+ MCP tools, 80 wiki pages, and 6 vertical plugins create a
   documentation surface that is substantially harder to navigate than Maestro's.

3. **Historical supply chain incident**: An obfuscated preinstall script was present through
   multiple alpha versions and removed in v3.5.3. Claims of "zero production vulnerabilities"
   should be read with this history in mind.

4. **Quantum/neural marketing inflation**: Plugin names include "quantum-topology optimization"
   and "hyperbolic Poincaré ball representations." Practical impact on developer workflows is
   unclear from documentation alone.

5. **Node.js runtime lock-in**: WASM performance benefits require a native build environment.
   In minimal environments, modules fall back to pure JS.

---

## SEO Landscape

- GitHub repo is heavily keyword-optimized (20 topics including agentic-ai, swarm-intelligence,
  mcp-server, claude-code-skills)
- DeepWiki indexed analysis: https://deepwiki.com/ruvnet/ruflo
- Third-party coverage: mlhive.com, aiany.app, openclawapi.org
- No independent peer-reviewed benchmarks or case studies found as of research date

---

## Prioritized Gap Summary

**Closest to Maestro's model** (markdown-first, shell-scriptable, no new runtime dependencies):
- Scout/Explorer agent pattern — new agent role, minimal infrastructure
- SPARC methodology as a skill workflow — structured phases, uses existing dev-loop primitives
- Production validator — mock-detection script + pre-ship hook, uses existing shell tooling
- London School TDD swarm — extends test-gen with contract-sharing protocol
- Three-tier memory model — add explicit procedural layer to existing memory skill

**Requires new infrastructure** (persistent runtime or inter-agent communication):
- Work-stealing load balancer — needs inter-agent runtime state visibility
- Adaptive topology switching — needs runtime monitoring of agent performance metrics
- SLA monitoring with real-time alerting — needs persistent monitoring process
- CRDT-based distributed state — needs conflict-free data structure library
- Benchmark CUSUM regression detection — needs statistical computation module

**Requires external dependencies**:
- E2B sandbox execution — requires E2B account and API integration
- Agentic payments — requires payment provider integration and mandate management
- Federated neural training — requires distributed node infrastructure
- Agentic Jujutsu VCS — requires alternative VCS implementation beyond Git

**Domain-specific / long-horizon**:
- Vertical domain plugins (healthcare, legal, finance)
- Gossip protocol coordination for large swarms
- PageRank agent criticality analysis
- Post-quantum cryptography (SHA3-512 + HQC-128)
- Multi-repository org-wide swarm coordination

---

## Sources

All findings traced to verified URLs fetched during this research session:

- https://github.com/ruvnet/ruflo
- https://raw.githubusercontent.com/ruvnet/ruflo/main/README.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/AGENTS.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/sparc-methodology/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/claims/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/agent-multi-repo-swarm/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/agent-production-validator/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/agent-tdd-london-swarm/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/agent-scout-explorer/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/agent-adaptive-coordinator/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/agent-topology-optimizer/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/agent-pagerank-analyzer/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/agent-load-balancer/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/agent-sandbox/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/agent-agentic-payments/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/agent-release-swarm/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/flow-nexus-neural/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/agentdb-memory-patterns/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/agent-performance-monitor/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/agent-benchmark-suite/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/agentic-jujutsu/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/agent-gossip-coordinator/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/agent-crdt-synchronizer/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/hive-mind/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/hooks-automation/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/verification-quality/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/security-audit/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/agent-code-review-swarm/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/agent-project-board-sync/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/agentdb-learning/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/agent-sona-learning-optimizer/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/reasoningbank-intelligence/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/workflow-automation/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/agent-collective-intelligence-coordinator/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/agent-resource-allocator/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/agent-swarm-memory-manager/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/agent-v3-queen-coordinator/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/agent-v3-memory-specialist/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/skill-builder/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.claude-plugin/docs/PLUGIN_SUMMARY.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/agent-github-modes/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/github-multi-repo/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/agent-quorum-manager/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/agent-raft-manager/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/agent-byzantine-coordinator/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/neural-training/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/agent-migration-plan/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/agentdb-vector-search/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/agentdb-optimization/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/agent-release-swarm/SKILL.md
- https://raw.githubusercontent.com/ruvnet/ruflo/main/.agents/skills/agent-benchmark-suite/SKILL.md
