---
name: commit-score
description: "Score each commit on quality: tests, conventions, message quality, cleanliness. Track average per project."
---

# Commit Quality Score

Rate each commit on 4 dimensions (0-25 each, total 0-100).

## Dimensions

### 1. Tests Included (0-25)

| Condition | Score |
|-----------|-------|
| Test files in the commit + all passing | 25 |
| Test files in the commit + some failing | 15 |
| No test files but existing tests still pass | 10 |
| No test files and no test infrastructure | 0 |

### 2. Conventions Followed (0-25)

Check against DNA patterns:

| Check | Points |
|-------|--------|
| File naming matches convention | 5 |
| Export style matches (named vs default) | 5 |
| Import ordering follows project pattern | 5 |
| Component/function structure matches | 5 |
| Styling approach matches (Tailwind, CSS modules, etc.) | 5 |

### 3. Message Quality (0-25)

| Check | Points |
|-------|--------|
| Follows conventional commits (type(scope): desc) | 10 |
| Description is meaningful (not "fix" or "update") | 5 |
| Body explains WHY, not just WHAT | 5 |
| References story/issue if applicable | 5 |

### 4. Code Cleanliness (0-25)

| Check | Points |
|-------|--------|
| No TODO/FIXME/HACK introduced | 10 |
| No console.log left in | 5 |
| No commented-out code | 5 |
| No debugging artifacts | 5 |

## Rating

| Score | Badge |
|-------|-------|
| 90-100 | Gold |
| 70-89 | Silver |
| 50-69 | Bronze |
| <50 | Needs Improvement |

## Output

```
  Commit score: 85/100 (Silver)
    Tests       25/25
    Conventions 20/25  (default export used once)
    Message     20/25  (missing body)
    Clean       20/25  (1 TODO added)
```

## Tracking

Append to `.maestro/trust.yaml`:

```yaml
commit_scores:
  average: 82
  last_5: [85, 80, 90, 75, 80]
  gold: 3
  silver: 8
  bronze: 2
```

Average commit score factors into trust level calculation.
