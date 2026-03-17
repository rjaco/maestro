---
template: architecture
description: "Architecture document template — produced by the architecture skill"
---

# Architecture: [Project or Feature Name]

**Date:** [YYYY-MM-DD]
**Status:** [draft / approved / superseded]

## Tech Stack

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| Framework | [choice] | [why] |
| Language | [choice] | [why] |
| Database | [choice] | [why] |
| Hosting | [choice] | [why] |
| Styling | [choice] | [why] |
| Auth | [choice] | [why] |

## Data Model

```
Entity: [name]
  - id: uuid (PK)
  - [field]: [type] [constraints]
  -> [relationship] to [other entity]
```

## API Design

```
[METHOD] [path]
  Auth: [public / authenticated / admin]
  Input: { field: type }
  Output: { field: type }
```

## Component Architecture

```
src/
  app/
    [route]/page.tsx       — [description]
  components/
    [Component].tsx        — [description]
  lib/
    [module].ts            — [description]
```

## Infrastructure

- **Hosting:** [platform and rationale]
- **CI/CD:** [pipeline description]
- **Monitoring:** [error tracking, performance, logging]
- **Caching:** [cache layers and invalidation strategy]
- **Security:** [HTTPS, CSP, CORS, secrets, sanitization]
