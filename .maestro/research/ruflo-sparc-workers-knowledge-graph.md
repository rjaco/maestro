# Ruflo — SPARC, Workers, Knowledge Graph, and Remaining Deep-Dives

**Date**: 2026-03-18
**Researcher**: Maestro Research Agent
**Source Repo**: https://github.com/ruvnet/ruflo (21.6k stars)
**Prior files**: `ruflo.md` (full profile), `ruflo-gaps.md` (gap analysis)

This document answers specific questions about Ruflo features not fully covered in
prior research files. It does not repeat what is already in `ruflo.md` or `ruflo-gaps.md`.

---

## 1. SPARC Methodology — What It Is

SPARC is a five-phase structured development lifecycle enforced as a first-class agent workflow.
Each phase has a dedicated agent. Phase gates are enforced by the Truth Verification System.

**Phases**:

| Phase | Agent | What It Does |
|-------|-------|-------------|
| **S**pecification | `sparc-specification` | Clarify objectives, scope, constraints, acceptance criteria. No hardcoded env vars allowed. |
| **P**seudocode | `sparc-pseudocode` | High-level logic with TDD anchors. Output: structured algorithm outline. |
| **A**rchitecture | `sparc-architecture` | System structure, service boundaries, extensible diagrams. |
| **R**efinement | `sparc-refinement` | TDD implementation, debugging, security review, optimization. |
| **C**ompletion | `sparc-completion` | Integration, documentation, monitoring setup, final quality gates. |

**Trigger condition**: Invoked when a task is classified as new-feature, complex implementation,
architectural change, or unclear requirements. Skipped for bug fixes, documentation, and
configuration changes to prevent over-engineering.

**CLI surface**:
```bash
npx @claude-flow/cli hooks route --task "specification: [requirements]"
npx @claude-flow/cli hooks route --task "pseudocode: [feature]"
npx @claude-flow/cli hooks route --task "architecture: [design]"
npx @claude-flow/cli hooks route --task "refinement: [feedback]"
npx @claude-flow/cli hooks route --task "completion: [final checks]"
```

**16 SPARC mode commands** exposed as Claude Code slash commands:
`/sparc-architect`, `/sparc-code`, `/sparc-tdd`, `/sparc-debug`, `/sparc-security-review`,
`/sparc-docs-writer`, `/sparc-integration`, `/sparc-post-deployment-monitoring-mode`,
`/sparc-refinement-optimization-mode`, `/sparc-ask`, `/sparc-devops`, `/sparc-tutorial`,
`/sparc-supabase-admin`, `/sparc-spec-pseudocode`, `/sparc-mcp`, `/sparc-sparc`

**SPARC orchestrator** (`/sparc-sparc`): decomposes complex objectives into sub-tasks routed
to the appropriate SPARC mode agents using `new_task`. Validates outputs at each phase gate:
- Files < 500 lines
- No hardcoded env vars
- Modular, testable outputs
- All subtasks end with `attempt_completion`

Source: `.agents/skills/sparc-methodology/SKILL.md`, `.claude/commands/sparc/`, `.claude/commands/sparc.md`

---

## 2. Scout/Explorer Agents — How They Work

The scout-explorer is a read-only reconnaissance agent. It explores before any modification
agents are dispatched. It reports findings to shared memory immediately and does not modify
files or make decisions.

**Three exploration strategies**:

1. **Breadth-first survey**: rapid landscape scan to identify high-level patterns; marks areas
   for deep inspection; produces initial map for all subsequent agents.

2. **Depth-first investigation**: targeted deep-dive into a specific region; documents every detail;
   identifies hidden issues; produces comprehensive analysis for that area.

3. **Continuous patrol**: ongoing monitoring for changes and anomalies; maintains situational
   awareness for long-running swarms; alerts on deviation from known state.

**What a scout can discover**:
- Codebase structure map (directories, key files, dependencies, design patterns)
- Dependency analysis (total count, critical deps, CVE vulnerabilities, outdated packages)
- Performance bottlenecks (N+1 queries, large bundles, CPU/memory metrics by location)
- Security threats (injection vulnerabilities, unvalidated inputs) — reported as immediate alerts
- Optimization opportunities (parallelizable operations, refactor candidates) — annotated with effort/impact

**Memory coordination pattern**: all findings stored immediately to shared memory namespace
`coordination` under structured keys like `swarm$shared$discovery-[timestamp]`. Importance is
classified as critical/high/medium/low. Other agents query this namespace before acting.

**Reports to**: queen-coordinator (strategic), collective-intelligence (pattern analysis),
swarm-memory-manager (archival).

**Does not do**: modify discovered code, make decisions on findings, duplicate peer scouts' work.

Source: `.agents/skills/agent-scout-explorer/SKILL.md`, `.claude/agents/hive-mind/scout-explorer.md`

---

## 3. Production Validators — What They Are

A production validator is a deployment-gate agent that blocks release if the codebase contains
implementation placeholders or fails real-infrastructure integration checks.

**Mock detection patterns**:
- Variable/class names prefixed with `mock`, `fake`, `stub`
- TODO/FIXME comments (in production code paths, not test files)
- `throw new Error('not implemented')` or similar stubs
- In-memory databases where a real connection is expected

**Integration checks** (run against real, non-test infrastructure):
- Real database: full CRUD operations, persistence verification, cascade behavior
- External APIs: actual HTTP calls with test credentials; error handling under real failure conditions
- Cache (Redis): actual connect/set/get/delete cycles
- Email (SMTP): real message delivery, not mock transport

**Performance gates** (run at production-like data volumes):
- p95 response time under 100 concurrent requests (default: < 5s total, < 50ms avg)
- Sustained load: 95% success rate minimum over 60 seconds at 10 RPS

**Deployment hooks**:
```bash
# Pre-deployment: scan for mocks
grep -r "mock\|fake\|stub" src/ --exclude-dir=__tests__

# Post-deployment: validate health endpoint returns all dependencies healthy
# Auto-rollback via git if health check fails after deploy
```

**Relationship to anti-drift**: the production validator is the final gate in the anti-drift
chain. Anti-drift prevents specification from diverging during development;
the production validator prevents mock-based shortcuts from reaching production.

Source: `.agents/skills/agent-production-validator/SKILL.md`, `.claude/agents/testing/production-validator.md`

---

## 4. London School TDD — The Approach

Ruflo implements London School (mockist) TDD as a multi-agent swarm pattern, not just
a single-agent testing approach.

**Core principle**: test behavior (how objects collaborate) not state (what they contain).
Mocks define contracts. Contracts drive design.

**Outside-in flow enforced by the swarm**:
1. Acceptance test (user-facing behavior) written first
2. Mock contracts derived from acceptance test define collaborator interfaces
3. Integration tests validate collaboration patterns between objects
4. Unit tests verify individual object responsibilities against mocks
5. Implementation written to satisfy the mock contracts

**Multi-agent coordination additions**:
- Shared mock contracts: all agents in the swarm agree on mock definitions before implementation
  begins; contracts are versioned and stored in shared memory namespace
- Cross-agent contract evolution: when requirements change, mock updates propagate automatically
  to dependent agents — no manual synchronization
- Bidirectional feedback: unit test agents report interaction patterns up to integration agents;
  architecture agents receive behavioral insights from the TDD agents below them

**Swarm coordination hooks**:
```typescript
beforeAll(async () => {
  await swarmCoordinator.notifyTestStart('unit-tests');
});
afterAll(async () => {
  await swarmCoordinator.shareResults(testResults);
  contractMonitor.verifyInteractions(currentTest.mocks);
  contractMonitor.reportToSwarm(interactionResults);
});
```

**Key distinction from classical TDD**: the mock contract is a coordination artifact shared
between agents, not just a test implementation detail.

Source: `.agents/skills/agent-tdd-london-swarm/SKILL.md`, `.claude/agents/testing/tdd-london-swarm.md`

---

## 5. Consensus Mechanisms

Ruflo implements four production consensus protocols as separately-configured agents, plus
a higher-level consensus coordinator.

### Protocols

| Protocol | Fault Model | Threshold | Best Use |
|----------|-------------|-----------|----------|
| **Raft** | Crash faults | 50%+ majority (leader-based) | Coding swarms (anti-drift), default for hive-mind |
| **Byzantine (pBFT)** | Malicious + crash | 2/3 majority (f < n/3 faulty) | Security decisions, production deployments |
| **Gossip** | Network partitions | Eventually consistent | Large swarms (50+ agents), eventual coordination |
| **CRDT** | Concurrent updates | Commutative, idempotent | Shared state with no coordination overhead |

### pBFT Three-Phase Protocol
1. **Pre-prepare**: primary broadcasts proposal with sequence number + digest
2. **Prepare**: nodes broadcast prepare messages; 2f+1 confirms move to commit phase
3. **Commit**: nodes broadcast commit; 2f+1 commits → result accepted
4. **View change**: triggers when primary fails; new primary elected

The pBFT implementation supports view change (primary failure recovery) and periodic checkpointing.

### Consensus Coordinator Agent
Uses a sublinear solver MCP tool (`mcp__sublinear-time-solver__solve`) for fast consensus
computation. For voting power analysis, uses PageRank (`mcp__sublinear-time-solver__pageRank`)
to weight votes by agent influence score. Sublinear complexity enables consensus on large
swarms without O(n²) message overhead.

**Agent quarantine**: if a Byzantine fault is detected (agent deviating from consensus),
the agent is automatically quarantined without human intervention.

Source: `.agents/skills/agent-consensus-coordinator/SKILL.md`, `v3/@claude-flow/swarm/src/consensus/byzantine.ts`

---

## 6. Agent Booster Pattern

Agent Booster is a WASM-based code transformation engine that skips the LLM entirely for
mechanical edits. It uses AST analysis (not regex) and produces deterministic output in <1ms at $0.

**Supported transform intents**:

| Intent | Transform | Example |
|--------|-----------|---------|
| `var-to-const` | Convert `var`/`let` to `const` | `var x = 1` → `const x = 1` |
| `add-types` | Insert TypeScript type annotations | `function foo(x)` → `function foo(x: string)` |
| `add-error-handling` | Wrap in try/catch | Adds structured error handling |
| `async-await` | Convert `.then()` chains to async/await | Promise chains → `await` |
| `add-logging` | Insert `console.log` statements | Debug logging at function entry/exit |
| `remove-console` | Strip all `console.*` calls | Pre-production cleanup |

**Hook signal pattern**:
- Hook emits `[AGENT_BOOSTER_AVAILABLE]` when the incoming task matches a supported intent
- Receiving Claude Code session should use the Edit tool directly, not call the LLM
- Claimed 352x speedup vs. calling a full cloud model (baseline: cloud model, not a local quantized model)

**Stack**:
- Implementation: Rust compiled to WASM via NAPI bindings
- Fallback: WASM → pure JS if NAPI build unavailable
- Part of 3-tier routing: Tier 1 (WASM) → Tier 2 (Haiku) → Tier 3 (Sonnet/Opus)

**Optimization claim**: combined with token caching, ReasoningBank retrieval, and batch optimization,
Ruflo claims 30–50% total token reduction across typical workflows. Not independently verified.

Source: `CLAUDE.md` (ADR-026 section), `README.md` Agent Booster section

---

## 7. Knowledge Graph Implementation

Ruflo's knowledge graph lives in `@claude-flow/memory` as `MemoryGraph`. It is a pure
TypeScript PageRank + community detection layer over the HNSW vector memory backend.

**Graph structure**:
- Nodes: memory entries (id, category, confidence, accessCount, createdAt)
- Edges: typed relationships between entries

**Five edge types**:
| Type | Meaning |
|------|---------|
| `reference` | Explicit reference (`entry.references` array) |
| `similar` | Auto-created when cosine similarity exceeds threshold (default 0.8) |
| `temporal` | Entries created close in time |
| `co-accessed` | Entries retrieved together frequently |
| `causal` | Explicit causal dependency |

**PageRank**:
- Damping factor: 0.85 (configurable)
- Convergence: 1e-6 threshold, max 50 iterations
- Purpose: identify structurally influential memory entries (high PageRank = widely referenced patterns)

**Community detection**: label propagation algorithm (default) or Louvain algorithm.
Detects clusters of related memories to group related patterns.

**Graph-aware search ranking**: results are scored by combining vector similarity score
with PageRank rank and community membership:
```
combinedScore = vectorScore * (1 + alpha * pageRank) * communityBonus
```

**Persistence**: graph is built from the HNSW backend on demand; not persisted separately.
Rebuild cost is O(n + e) where n = nodes, e = edges. Max 5,000 nodes by default.

**ADR-049** governs the knowledge graph's confidence lifecycle: entries flow through
states (confirmed → probable → uncertain → contested → refuted) based on evidence accumulation.
Child confidence is bounded by parent confidence in inference chains.

**UncertaintyLedger** (separate from the graph): probabilistic belief tracking with
explicit confidence intervals. Beliefs decay at 1% per hour. Evidence adds or subtracts
from belief strength via weighted factors. This is Ruflo's "anti-hallucination" layer for
agent knowledge claims.

Source: `v3/@claude-flow/memory/src/memory-graph.ts`,
`v3/@claude-flow/guidance/docs/guides/knowledge-management.md`

---

## 8. Claims System

A claims-based authorization framework governing which agent owns which capability at what
scope. Designed for least-privilege operation in multi-agent swarms.

**Seven permission types**:

| Claim | What It Grants |
|-------|---------------|
| `read` | File read access |
| `write` | File write access |
| `execute` | Shell command execution |
| `spawn` | Agent spawning |
| `memory` | Memory namespace access |
| `network` | Network calls |
| `admin` | Administrative operations |

**Four security tiers**:
- `minimal`: read only
- `standard`: read + write + execute
- `elevated`: standard + spawn + memory
- `admin`: all claims

**Scope patterns**: claims are scoped to resource patterns (e.g., write access limited
to `/src/**`, memory access limited to `memory:patterns` namespace).

**Human-agent handoff protocol**: human operators grant claims at task start; claims are
revoked on task completion. The audit trail records every grant and revocation.

**Work-stealing integration**: if an agent's task queue exceeds capacity, its low-priority
claims can be reassigned to an idle agent by the load balancer without human intervention.
This is "stealable tasks" — ownership transfers, not just assignment.

**CLI**:
```bash
npx claude-flow claims check --agent agent-123 --claim write
npx claude-flow claims grant --agent agent-123 --claim write --scope "/src/**"
npx claude-flow claims revoke --agent agent-123 --claim write
npx claude-flow claims list --agent agent-123
```

Source: `.agents/skills/claims/SKILL.md`

---

## 9. Anti-Drift Mechanisms

Anti-drift is Ruflo's system for preventing agent implementations from diverging from
their specifications over time. It operates at multiple levels.

**Level 1 — Swarm topology**: hierarchical topology (queen + workers) is explicitly
the "anti-drift coding swarm" topology. The queen maintains authoritative state;
workers must converge to queen decisions via Raft consensus.

**Level 2 — Anti-drift-validator agent**: a dedicated agent that:
- Compares current implementation state against original specification (stored in memory)
- Checks for scope creep (new functionality not in spec)
- Detects spec violations (missing required features)
- Runs as a continuous validator during long-running swarms

**Level 3 — CLAUDE.md discipline**: configuration rules enforced at session start:
```
maxAgents: 6-8 for tight coordination
topology: hierarchical
consensus: raft
checkpoints: post-task hooks (frequent)
shared memory namespace: all agents use same namespace
task cycles: short with verification gates
```

**Level 4 — UncertaintyLedger**: beliefs about system state are tracked with confidence
scores that decay over time. An agent acting on a stale belief (low confidence) will
query memory before proceeding, preventing drift from incorrect assumptions.

**Level 5 — Post-task hooks + checkpoint workers**: after every task, the `post-task`
hook runs the `swarm` background worker, which validates agent coordination state.
The `adr` worker runs every 15 minutes to check ADR compliance across the codebase.

Source: `CLAUDE.md` (anti-drift section), `.agents/skills/agent-adaptive-coordinator/SKILL.md`,
`v3/@claude-flow/hooks/src/workers/index.ts`

---

## 10. The 12 Background Workers — Reconciliation

**Clarification on count**: the v3 `WORKER_CONFIGS` object in
`v3/@claude-flow/hooks/src/workers/index.ts` defines 11 workers. The worker-integration
skill (`.agents/skills/worker-integration/SKILL.md`) lists 8 trigger-based workers used
by the agent dispatch layer. These are two different worker systems that overlap.

**11 V3 scheduled workers** (from `WORKER_CONFIGS`, confirmed by source code):

| Worker | Priority | Interval | Purpose |
|--------|----------|----------|---------|
| `performance` | Normal | 5 min | Benchmark search, memory, startup performance |
| `health` | High | 5 min | Monitor disk, memory, CPU, processes |
| `patterns` | Normal | 15 min | Consolidate, dedupe, optimize learned patterns |
| `ddd` | Low | 10 min | Track DDD domain implementation progress |
| `adr` | Low | 15 min | Check ADR compliance across codebase |
| `security` | High | 30 min | Scan for secrets, vulnerabilities, CVEs |
| `learning` | Normal | 30 min | Optimize learning, SONA adaptation |
| `cache` | Background | 1 hour | Clean temp files, old logs, stale cache |
| `git` | Normal | 5 min | Track uncommitted changes, branch status |
| `swarm` | High | 1 min | Monitor swarm activity, agent coordination |
| `v3progress` | Normal | on-demand | Track v3 CLI/MCP/package migration progress |

**Note**: the README and earlier documentation cite "12 workers." The source code has 11 in
`WORKER_CONFIGS` plus `v3progress` registered separately. It is likely that "12" was the
correct count at some version point and one was added or renamed.

**8 trigger-based agent dispatch workers** (different system, from worker-integration skill):

| Trigger | Primary Agents | Pipeline Phases |
|---------|---------------|-----------------|
| `ultralearn` | researcher, coder | discovery → patterns → vectorization → summary |
| `optimize` | performance-analyzer, coder | static-analysis → performance → patterns |
| `audit` | security-analyst, tester | security → secrets → vulnerability-scan |
| `benchmark` | performance-analyzer | performance → metrics → report |
| `testgaps` | tester | discovery → coverage → gaps |
| `document` | documenter, researcher | api-discovery → patterns → indexing |
| `deepdive` | researcher, security-analyst | call-graph → deps → trace |
| `refactor` | coder, reviewer | complexity → smells → patterns |

These 8 are dispatched agents, not background daemons. They fire when a scheduled worker
detects conditions requiring LLM-based analysis (e.g., the `performance` worker detects
a regression → dispatches `benchmark` agent pipeline).

Source: `v3/@claude-flow/hooks/src/workers/index.ts`, `.agents/skills/worker-integration/SKILL.md`

---

## Sources

- https://github.com/ruvnet/ruflo/blob/main/.agents/skills/sparc-methodology/SKILL.md
- https://github.com/ruvnet/ruflo/blob/main/.agents/skills/agent-scout-explorer/SKILL.md
- https://github.com/ruvnet/ruflo/blob/main/.agents/skills/agent-production-validator/SKILL.md
- https://github.com/ruvnet/ruflo/blob/main/.agents/skills/agent-tdd-london-swarm/SKILL.md
- https://github.com/ruvnet/ruflo/blob/main/.agents/skills/agent-consensus-coordinator/SKILL.md
- https://github.com/ruvnet/ruflo/blob/main/.agents/skills/claims/SKILL.md
- https://github.com/ruvnet/ruflo/blob/main/.agents/skills/worker-integration/SKILL.md
- https://github.com/ruvnet/ruflo/blob/main/v3/@claude-flow/hooks/src/workers/index.ts
- https://github.com/ruvnet/ruflo/blob/main/v3/@claude-flow/memory/src/memory-graph.ts
- https://github.com/ruvnet/ruflo/blob/main/v3/@claude-flow/swarm/src/consensus/byzantine.ts
- https://github.com/ruvnet/ruflo/blob/main/v3/@claude-flow/guidance/docs/guides/knowledge-management.md
- https://github.com/ruvnet/ruflo/blob/main/CLAUDE.md
- https://github.com/ruvnet/ruflo/blob/main/.claude/commands/sparc.md
