# Token Budget Profiles

Allocation breakdowns per agent type showing how the total budget distributes across context categories.

## Implementer (T3)

| Category | Tokens | Notes |
|----------|--------|-------|
| Story spec | 300 | Title, description, acceptance criteria, file list |
| Rules | 200 | Filtered CLAUDE.md rules for affected files |
| Patterns | 300 | Relevant code conventions and examples |
| Interfaces | 400 | Type definitions, function signatures, API contracts |
| File contents | 2,000 | Targeted line ranges of files to modify/reference |
| QA feedback | 200 | Previous iteration feedback for this story |
| **Total** | **3,400** | Well within T3 budget (4,000-8,000) |

## QA Reviewer (T3)

| Category | Tokens | Notes |
|----------|--------|-------|
| Story spec | 300 | Acceptance criteria are the review checklist |
| Code diff | 2,000 | Full diff produced by the implementer |
| Rules | 200 | CLAUDE.md rules relevant to modified files |
| Patterns | 200 | Conventions the diff should conform to |
| Test output | 500 | Build, lint, type-check, test results |
| **Total** | **3,200** | Lean review package |

## Self-Heal (T4)

| Category | Tokens | Notes |
|----------|--------|-------|
| Error output | 200 | Stack trace, lint error, or type error message |
| File content | 1,000 | Affected file around the error location |
| Fix pattern | 200 | Known resolution pattern if available |
| **Total** | **1,400** | Minimal package for targeted fixes |

## Strategist (T1)

| Category | Tokens | Notes |
|----------|--------|-------|
| Vision | 1,000 | Product vision, positioning, target audience |
| Research | 5,000 | Market analysis, competitor features, user feedback |
| Roadmap | 1,000 | Milestone definitions and progress |
| Market data | 3,000 | Industry trends, pricing, growth opportunities |
| **Total** | **10,000** | Full strategic picture without implementation details |

## Architect (T2)

| Category | Tokens | Notes |
|----------|--------|-------|
| Architecture | 2,000 | System layers, data flow, deployment topology |
| Component map | 1,500 | Module boundaries, dependency graph |
| API contracts | 1,500 | Route definitions, request/response schemas |
| Data model | 1,500 | Database schema, relationships, migration history |
| DNA | 1,000 | Tech stack, patterns, conventions summary |
| Milestone scope | 1,000 | Current milestone stories and their relationships |
| **Total** | **8,500** | Technical depth without strategic or marketing context |

## Orchestrator (T0)

| Category | Tokens | Notes |
|----------|--------|-------|
| All of the above | Variable | Full context from every category |
| Agent results | 2,000 | Summaries of completed story outcomes |
| State | 500 | Current progress, blockers, trust scores |
| Token ledger | 300 | Spend tracking and budget remaining |
| **Total** | **15,000-25,000** | Varies by project size and session length |
