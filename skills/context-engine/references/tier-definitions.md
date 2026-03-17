# Context Tier Definitions

Each tier defines what context categories an agent receives. Tiers are matched to agent roles by default but can be overridden by the delegation skill when task complexity warrants it.

## T0 — Orchestrator (CEO)

**Budget:** 15,000-25,000 tokens

**Receives:**
- Full project vision and roadmap
- Research summaries and competitive intelligence
- Project DNA (tech stack, patterns, conventions, architecture)
- Current state (active stories, progress, blockers)
- All story specs and their statuses
- Agent results from completed stories (summaries, not full diffs)
- Trust scores and model performance history
- Token spend ledger and budget status

**Excluded:** Nothing. The orchestrator needs the full picture to make coordination decisions.

**Typical agents:** Session orchestrator, opus-loop coordinator, milestone planner.

## T1 — Strategic (CTO)

**Budget:** 10,000-15,000 tokens

**Receives:**
- Vision document and product positioning
- Research findings (market analysis, competitor features, user needs)
- Roadmap and milestone definitions
- Competitive intelligence and market data
- Project DNA summary (tech stack, high-level architecture)
- Current milestone scope and progress

**Excluded:** Source file contents, test code, implementation details, individual story diffs, QA feedback on specific stories, line-level patterns.

**Typical agents:** Strategy advisor, research synthesizer, roadmap planner.

## T2 — Architect (Tech Lead)

**Budget:** 8,000-12,000 tokens

**Receives:**
- Architecture documentation (system layers, data flow, component boundaries)
- Component map and module dependency graph
- API design contracts and data model schemas
- Current milestone scope and all stories within it
- Project DNA (full technical detail)
- Relevant CLAUDE.md sections (architecture, file organization, gotchas)
- Type definitions and interface contracts

**Excluded:** Marketing strategy, competitive analysis, monetization plans, user personas, content strategy, individual QA iteration feedback.

**Typical agents:** Architecture reviewer, API designer, data modeler, decompose skill.

## T3 — Implementer (Developer)

**Budget:** 4,000-8,000 tokens

**Receives:**
- Current story spec (title, description, acceptance criteria, files list)
- Relevant source file contents (targeted line ranges, not full files)
- Applicable code patterns and conventions (filtered by story type and file paths)
- Interface contracts and type definitions the story must conform to
- QA feedback from previous iterations of THIS story
- Applicable CLAUDE.md rules (only rules mentioning affected files/directories)

**Excluded:** Other stories in the milestone, project roadmap, research documents, vision, competitive intel, unrelated patterns, QA history from other stories.

**Typical agents:** Code implementer, test writer, migration author, component builder.

## T4 — Fix (Specialist)

**Budget:** 1,000-3,000 tokens

**Receives:**
- Error message (full stack trace or lint/type error)
- Content of the affected file(s) (targeted to the error location +/- 20 lines)
- Relevant fix pattern if one exists (e.g., "missing import", "type mismatch resolution")

**Excluded:** Story context, project state, DNA, research, roadmap, other files, QA history, conventions beyond the immediate fix scope.

**Typical agents:** Self-heal agent (build fix, lint fix, type error fix), hot-patch agent.
