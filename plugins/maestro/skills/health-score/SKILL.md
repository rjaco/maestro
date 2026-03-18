---
name: health-score
description: "Calculate a project health score (0-100) from test coverage, type safety, lint compliance, dependency freshness, and tech debt. Tracks trends."
effort: low
maxTurns: 3
disallowedTools:
  - Write
  - Edit
---

# Project Health Score

A single number (0-100) reflecting overall project quality. Composed of 5 dimensions, each worth 0-20 points.

## Dimensions

### 1. Test Coverage (0-20)

```bash
npm test -- --coverage 2>/dev/null | grep 'All files' | awk '{print $NF}'
```

| Coverage | Score |
|----------|-------|
| 80%+ | 20 |
| 60-79% | 15 |
| 40-59% | 10 |
| 20-39% | 5 |
| <20% or no tests | 0 |

### 2. Type Safety (0-20)

```bash
tsc --noEmit 2>&1 | grep -c 'error TS'
```

| Errors | Score |
|--------|-------|
| 0 | 20 |
| 1-5 | 15 |
| 6-15 | 10 |
| 16-30 | 5 |
| 30+ | 0 |

### 3. Lint Compliance (0-20)

```bash
npm run lint 2>&1 | grep -c 'error\|warning'
```

| Issues | Score |
|--------|-------|
| 0 | 20 |
| 1-10 | 15 |
| 11-30 | 10 |
| 31-50 | 5 |
| 50+ | 0 |

### 4. Dependency Freshness (0-20)

```bash
npm outdated --json 2>/dev/null | jq 'length'
```

| Outdated | Score |
|----------|-------|
| 0 | 20 |
| 1-5 | 15 |
| 6-15 | 10 |
| 16-30 | 5 |
| 30+ | 0 |

### 5. Tech Debt Density (0-20)

```bash
grep -rn 'TODO\|FIXME\|HACK\|XXX' src/ 2>/dev/null | wc -l
```

| Items | Score |
|-------|-------|
| 0-5 | 20 |
| 6-15 | 15 |
| 16-30 | 10 |
| 31-50 | 5 |
| 50+ | 0 |

## Total Score

Sum of 5 dimensions (0-100):

| Score | Rating | Color |
|-------|--------|-------|
| 90-100 | Excellent | Green |
| 70-89 | Good | Blue |
| 50-69 | Fair | Yellow |
| 30-49 | Poor | Red |
| 0-29 | Critical | Red bold |

## Output

```
+---------------------------------------------+
| Health Score: 78 / 100 (Good)               |
+---------------------------------------------+

  Tests       [================    ] 15/20  76% coverage
  Types       [====================] 20/20  0 errors
  Lint        [===============     ] 15/20  8 warnings
  Deps        [================    ] 16/20  3 outdated
  Tech Debt   [============        ] 12/20  22 TODOs

  Trend: 78 -> 78 (stable since last check)
```

## Tracking

Save score to `.maestro/logs/health-score.md`:

```markdown
# Health Score History

| Date | Score | Tests | Types | Lint | Deps | Debt |
|------|-------|-------|-------|------|------|------|
| 2026-03-17 | 78 | 15 | 20 | 15 | 16 | 12 |
| 2026-03-15 | 72 | 12 | 20 | 15 | 15 | 10 |
```

## Integration

- Displayed in status line (if configured)
- Included in daily briefing (brain skill)
- Shown in `/maestro doctor` diagnostics
- Tracked over time for trend analysis

## Output Contract

```yaml
output_contract:
  file_pattern: ".maestro/logs/health-score.md"
  required_sections:
    - "## Health Score History"
  required_frontmatter:
    score: integer
    rating: enum(excellent, good, fair, poor, critical)
```
