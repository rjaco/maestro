# Roadmap Generator — Milestones from Vision and Research

Generates a milestone-based roadmap from the vision document and research brief. Each milestone is a shippable increment that delivers measurable value.

## Inputs

- `.maestro/vision.md` — The North Star, scope definition, success criteria
- `.maestro/research-brief.md` — Synthesized research findings (if research was run)
- `.maestro/dna.md` — Project DNA for tech stack and existing patterns

## Milestone Design Principles

1. **Each milestone is independently shippable.** A user could stop after any milestone and have a working, valuable product increment.
2. **Milestones build on each other.** M2 assumes M1 is complete. No circular dependencies.
3. **Early milestones reduce risk.** Foundation, data model, and core flows come first. Polish and optimization come last.
4. **Milestones are right-sized.** Target 3-6 stories per milestone. Fewer than 3 means the milestone is too granular. More than 8 means it should be split.
5. **The first milestone is always the smallest.** Get something working fast. Build momentum.

## Milestone Generation Process

### Step 1: Identify Shippable Increments

From the vision's scope section, identify natural breakpoints:

| Common Pattern | Milestone Sequence |
|----------------|-------------------|
| Full-stack app | M1: Data + API skeleton. M2: Core UI. M3: Auth + permissions. M4: Advanced features. M5: Polish + launch. |
| API/Backend | M1: Schema + CRUD. M2: Business logic. M3: Auth + rate limiting. M4: Integrations. M5: Monitoring + docs. |
| Frontend rebuild | M1: Design system + layout. M2: Core pages. M3: Interactive features. M4: Performance + a11y. M5: Launch. |
| Data pipeline | M1: Ingestion. M2: Transform + validate. M3: Storage + query. M4: Monitoring + alerts. M5: Backfill + scale. |

Adapt the pattern to the specific vision. Do not force-fit.

### Step 2: Write Milestone Specs

For each milestone, create `.maestro/milestones/MN-slug.md` using the milestone template:

```yaml
---
id: MN
name: "Descriptive milestone name"
depends_on: [list of milestone IDs]
estimated_stories: N
estimated_tokens: NNNNN
estimated_cost: N.NN
research_inputs: [list of research dimension files relevant to this milestone]
---

## Acceptance Criteria

1. [Specific, measurable criterion that proves the milestone is complete]
2. [Another criterion — must be verifiable by running code or inspecting output]
3. [At least 3 criteria per milestone]

## Scope

### In Scope
- [Feature or capability included in this milestone]
- [Another feature]

### Out of Scope
- [Feature explicitly deferred to a later milestone]
- [Clarifies boundaries to prevent scope creep]
```

### Step 3: Calculate Estimates

For each milestone, estimate:

- **Stories:** Based on scope complexity and the decompose skill's historical patterns
- **Tokens:** Stories x average tokens per story (from token-ledger history, or defaults: simple 20K, medium 35K, complex 50K)
- **Cost:** Tokens x model pricing (assume 70% Sonnet, 20% Opus for QA, 10% Haiku for fixes)
- **Time:** Rough wall-clock estimate based on story count and agent throughput

### Step 4: Generate Roadmap Summary

Write `.maestro/roadmap.md`:

```markdown
# Roadmap — [Product Name]

Generated from vision and research on [date].

| # | Milestone | Stories | Est. Cost | Status | Completed |
|---|-----------|---------|-----------|--------|-----------|
| M1 | [name] | ~[N] | ~$[N] | pending | — |
| M2 | [name] | ~[N] | ~$[N] | pending | — |
| M3 | [name] | ~[N] | ~$[N] | pending | — |
| | **Total** | **~[N]** | **~$[N]** | | |

## Dependency Graph

M1 -> M2 -> M3
            M2 -> M4
                  M4 -> M5

## Research Mapping

- M1 uses: 02-tech-stack, 03-architecture
- M2 uses: 07-user-research, 04-seo-content
- M3 uses: 05-monetization, 06-integrations
```

### Step 5: Present for Approval

Show the roadmap table and dependency graph to the user.

The user can:
- **Approve** — Proceed to execution
- **Reorder** — Change milestone sequence (within dependency constraints)
- **Skip** — Mark milestones to skip (note: skipped milestones cannot be depended on)
- **Add** — Request additional milestones
- **Modify** — Change scope, acceptance criteria, or estimates for specific milestones
- **Split** — Break a large milestone into smaller ones
- **Merge** — Combine small milestones

Update milestone files and roadmap.md with any changes before proceeding.

## Output

- `.maestro/milestones/MN-slug.md` for each milestone
- `.maestro/roadmap.md` summary table
- Updated `.maestro/state.local.md` with `total_milestones` count
