---
id: M4-17
slug: quickstart-expansion
title: "Quick-start template expansion — 12 templates for common project types"
type: enhancement
depends_on: []
parallel_safe: true
complexity: simple
model_recommendation: sonnet
---

## Acceptance Criteria

1. Enhanced `skills/quick-start/SKILL.md` with 12 templates (up from current count)
2. Templates covering:
   - **Web**: REST API, GraphQL API, Full-stack web app, Landing page
   - **CLI**: CLI tool, DevOps automation script
   - **Library**: NPM package, Python package
   - **Mobile**: React Native app, Flutter app
   - **Data**: Data pipeline, ML model training
3. Each template includes:
   - Name and description
   - Tech stack recommendation
   - Initial stories (3-5 per template)
   - Acceptance criteria for MVP
   - Estimated complexity (simple/medium/high)
4. Templates adapt to detected project type (from auto-init)
5. Mirror: skill in both root and plugins/maestro/

## Context for Implementer

Read the current `skills/quick-start/SKILL.md` first. Expand the template library.

Each template should be self-contained with enough information for the decompose skill to generate stories immediately. Format:

```markdown
### Template: REST API
**Stack**: Node.js + Express + PostgreSQL
**Complexity**: Medium (~5 stories)
**Stories**:
1. Project setup with TypeScript, ESLint, testing framework
2. Database schema and migration setup
3. Authentication endpoints (register, login, refresh)
4. Core CRUD endpoints for primary resource
5. Error handling, validation, and API documentation
```

Reference: skills/quick-start/SKILL.md (current)
Reference: skills/decompose/SKILL.md for story format
