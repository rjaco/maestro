---
name: swarm-topologies
description: "Define how multiple agents organize into a swarm. Six topologies with ASCII diagrams, use-case guidance, squad integration, and performance characteristics. Used by the orchestrator to select a coordination pattern before dispatch."
---

# Swarm Topologies

Defines the six structural patterns for multi-agent coordination in Maestro. The orchestrator selects a topology when more than one agent must work together on a feature, sprint, or project phase. The right topology reduces latency, avoids token waste, and matches the communication pattern the task actually needs.

## Topology Selection

Ask two questions before choosing:

1. **Is the task decomposable into independent pieces, or does each step depend on the last?**
   - Independent → Star or Parallel (Pipeline if order matters for quality)
   - Interdependent → Pipeline, Ring, or Hierarchical

2. **Is the goal well-defined or exploratory?**
   - Well-defined → Hierarchical, Star, or Pipeline
   - Exploratory → Mesh or Adaptive

---

## 1. Hierarchical

One lead agent coordinates a set of workers. The lead decomposes the goal, dispatches sub-tasks, collects results, and synthesizes a final output. Workers do not communicate with each other.

```
        [Lead]
       /  |   \
      /   |    \
  [W1]  [W2]  [W3]
```

**When to use:**
- Structured features with clear decomposition (stories, sprints, epics)
- Work where a single agent needs to maintain overall coherence
- Default Maestro mode: orchestrator is the lead, implementers are workers

**Agent communication pattern:**
- Lead → Workers: task assignment + context package
- Workers → Lead: structured status report (DONE / NEEDS_CONTEXT / BLOCKED)
- Workers never talk to each other directly

**Squad integration:**
- Works with any squad definition
- Lead role maps to the orchestrator, not to a squad agent
- Worker roles map to squad agents by their `role` field
- `orchestration_mode: parallel` in the squad file enables the lead to dispatch all workers at once

**Performance characteristics:**

| Dimension | Rating | Notes |
|-----------|--------|-------|
| Latency | Medium | Parallel workers help; lead synthesis adds overhead |
| Token cost | Medium | Lead processes all worker outputs |
| Quality | High | Lead maintains coherence across all sub-tasks |
| Failure handling | Good | Lead can re-dispatch a single failed worker |

---

## 2. Mesh

Every agent can communicate with every other agent. No central coordinator. Each agent reads all other agents' outputs and may revise its own work based on them.

```
  [A1] --- [A2]
   |  \   / |
   |   \ /  |
   |   / \  |
   |  /   \ |
  [A3] --- [A4]
```

**When to use:**
- Exploratory work: research sprints, brainstorming, threat modeling
- Problems with no clear decomposition — agents discover structure together
- Situations where agents benefit from seeing each other's partial conclusions

**Agent communication pattern:**
- All agents share a common context pool (e.g., a shared `.maestro/mesh-session.md`)
- Each agent appends its findings and reads the pool before each cycle
- Cycles terminate when no agent proposes further changes (convergence) or a round limit is hit

**Squad integration:**
- Assign all agents the `researcher` or `strategist` subagent type
- Do not use `implementer` agents in mesh — file edit conflicts are likely
- Set `orchestration_mode: sequential` to avoid write collisions on the shared pool

**Performance characteristics:**

| Dimension | Rating | Notes |
|-----------|--------|-------|
| Latency | High | Multiple rounds of mutual reads |
| Token cost | Highest | Every agent reads every other agent's output |
| Quality | Highest | Redundant cross-checking surfaces gaps |
| Failure handling | Fair | One stuck agent can block convergence |

---

## 3. Ring

Each agent passes its output to the next in a circular chain. The output of the last agent may loop back to the first for further refinement.

```
  [A1] → [A2] → [A3]
   ↑               |
   └───────────────┘
```

**When to use:**
- Iterative refinement cycles: implement → review → refine → review
- When a piece of work benefits from repeated passes by different specialists
- Quality-sensitive output where one review pass is not enough

**Agent communication pattern:**
- Agent N receives the output of Agent N-1 as its primary input
- Each agent may annotate, transform, or replace the payload
- The ring terminates after a fixed number of passes or when a quality gate is met (e.g., QA reviewer returns APPROVED)

**Squad integration:**
- Map ring positions to squad roles by order: e.g., `implementer → qa-reviewer → implementer`
- The orchestrator tracks ring position in `.maestro/state.local.md` as `ring_position`
- Set `orchestration_mode: sequential` — ring is inherently sequential

**Performance characteristics:**

| Dimension | Rating | Notes |
|-----------|--------|-------|
| Latency | High | Each pass blocks on the previous one |
| Token cost | Medium-High | Grows with number of passes |
| Quality | High | Each pass catches what the previous missed |
| Failure handling | Fair | A broken link halts the ring |

---

## 4. Star

A central coordinator dispatches tasks to all workers simultaneously and aggregates results when all complete. Workers have no knowledge of each other.

```
        [Hub]
      /  / \  \
     /  /   \  \
  [S1][S2] [S3][S4]
     \  \   /  /
      \  \ /  /
        [Hub]
```

**When to use:**
- Parallel independent tasks with a final aggregation step
- Content or data transformation where each chunk is independent
- Fan-out/fan-in: generate N variations, pick the best

**Agent communication pattern:**
- Hub → Spokes: identical or parameterized task + independent context slices
- Spokes → Hub: results in a uniform structured format
- Hub aggregates, deduplicates, or selects from spoke outputs

**Squad integration:**
- All spoke roles should be the same subagent type (typically `implementer` or `researcher`)
- Hub role maps to the orchestrator
- Set `orchestration_mode: parallel` — spokes run concurrently
- Cap at 3 parallel spokes (Maestro parallel dispatch limit)

**Performance characteristics:**

| Dimension | Rating | Notes |
|-----------|--------|-------|
| Latency | Low | All spokes run in parallel |
| Token cost | Medium | Hub aggregation is lightweight if spoke outputs are structured |
| Quality | Medium | No cross-spoke awareness — aggregation quality depends on the hub |
| Failure handling | Good | Failed spokes can be re-dispatched without touching others |

---

## 5. Pipeline

A linear chain where each agent adds to or transforms the work. Output flows in one direction. No loops.

```
  [A1] → [A2] → [A3] → [A4]
  research draft  edit  publish
```

**When to use:**
- Content pipelines: research → draft → edit → publish
- ETL-style workflows: extract → transform → load
- Progressive enhancement: scaffold → implement → test → document

**Agent communication pattern:**
- Agent N receives a payload from Agent N-1 and enriches or transforms it
- Each stage has a well-defined input schema and output schema
- The orchestrator acts as pipeline manager: advances the stage, handles stage failures

**Squad integration:**
- Map each pipeline stage to a squad role
- Stages should be different subagent types when specialization differs (e.g., `researcher` → `implementer` → `qa-reviewer`)
- Set `orchestration_mode: sequential`

**Performance characteristics:**

| Dimension | Rating | Notes |
|-----------|--------|-------|
| Latency | Highest | Fully sequential — each stage blocks the next |
| Token cost | Low | Each agent receives only the payload, not the full history |
| Quality | Medium-High | Specialization per stage improves each step |
| Failure handling | Fair | Pipeline must restart from the failed stage |

---

## 6. Adaptive

The topology is not fixed at the start. The orchestrator monitors task signals and transitions between topologies as the project evolves through phases.

```
Phase 1 (explore):   Mesh
        ↓
Phase 2 (plan):      Hierarchical
        ↓
Phase 3 (execute):   Star (parallel)
        ↓
Phase 4 (refine):    Ring
```

**When to use:**
- Complex projects that span multiple distinct phases
- Projects where the initial topology is unclear until the first phase completes
- Long-running sprints that begin with research and end with delivery

**Agent communication pattern:**
- Each phase uses the topology best suited to that phase's goal
- The orchestrator stores the current topology and phase in `.maestro/state.local.md` as `swarm_topology` and `swarm_phase`
- Transition triggers: phase completion signals, quality gate thresholds, or explicit user milestones

**Transition rules:**

| From | To | Trigger |
|------|----|---------|
| Mesh | Hierarchical | Research convergence (no new findings in last cycle) |
| Hierarchical | Star | Decomposition complete, stories are independent |
| Star | Ring | All stories implemented, quality gate not yet met |
| Ring | Done | QA reviewer returns APPROVED |
| Any | Mesh | Pivot detected — user changes goals mid-sprint |

**Squad integration:**
- Define a squad with roles covering all phases
- Assign `researcher`/`strategist` for early phases, `implementer`/`qa-reviewer` for execution
- The orchestrator swaps active topology by updating `swarm_topology` in state

**Performance characteristics:**

| Dimension | Rating | Notes |
|-----------|--------|-------|
| Latency | Varies | Each phase optimized independently |
| Token cost | Varies | Efficient per-phase; transition overhead is low |
| Quality | Highest | Right structure for each phase beats one fixed topology |
| Failure handling | Best | Can switch to a more resilient topology on failure |

---

## Topology Comparison

| Topology | Latency | Token Cost | Quality | Failure Resilience | Best For |
|----------|---------|------------|---------|-------------------|----------|
| Hierarchical | Medium | Medium | High | Good | Structured features |
| Mesh | High | Highest | Highest | Fair | Exploration, research |
| Ring | High | Medium-High | High | Fair | Iterative refinement |
| Star | Low | Medium | Medium | Good | Parallel independent tasks |
| Pipeline | Highest | Low | Medium-High | Fair | Content and ETL workflows |
| Adaptive | Varies | Varies | Highest | Best | Complex multi-phase projects |

---

## State Schema

The orchestrator tracks topology state in `.maestro/state.local.md`:

```yaml
swarm_topology: hierarchical      # hierarchical | mesh | ring | star | pipeline | adaptive
swarm_phase: execute              # phase label (adaptive only)
swarm_round: 2                    # current ring/mesh cycle count (ring and mesh only)
swarm_max_rounds: 5               # convergence limit (ring and mesh only)
```

---

## Integration with Delegation

The delegation skill reads `swarm_topology` before each dispatch. The topology determines:

1. Whether to dispatch agents in parallel (star) or sequentially (pipeline, ring)
2. Whether to include other agents' outputs in the context package (mesh, ring)
3. Whether to route results back through another agent (ring)
4. Which agent type to dispatch next (pipeline stage mapping)

If `swarm_topology` is absent, delegation defaults to `hierarchical`.
