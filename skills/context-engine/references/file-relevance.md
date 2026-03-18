# File Relevance Analysis

This document defines how the context engine scores file relevance for a given story before reading any files. Relevance scoring runs in the delegation phase and determines which files enter the context package.

---

## Relevance Signals

Each signal contributes a score to a file. A file's total score is the sum of all signals that fire for it.

### a. Name Match (weight: 3)

Extract key nouns from the story title and acceptance criteria. If any noun appears in a file's path or name, the file scores +3.

Examples:
- Story mentions "auth" → `src/auth/middleware.ts` scores +3
- Story mentions "user" → `src/models/user.ts` scores +3

Extraction rules:
- Tokenize the story title and each acceptance criterion line
- Keep nouns longer than 3 characters; discard stop words (the, and, for, with, etc.)
- Normalize to lowercase before matching
- Match against the full relative file path, not just the filename

### b. Import Graph (weight: 2)

If file A is already relevant (score > 0 from other signals) and file A imports file B, then file B scores +2.

Rules:
- Follow imports at most 2 levels deep
- Do not propagate beyond depth 2
- Detect import statements by language:
  - TypeScript/JavaScript: `import ... from '...'`, `require('...')`
  - Python: `import ...`, `from ... import`
  - Go: `import "..."` blocks
- Resolve relative paths from the importing file's location

### c. Git Proximity (weight: 2)

Files that are frequently committed together with already-relevant files score +2.

Command to compute co-change frequency:

```sh
git log --format='' --name-only | sort | uniq -c | sort -rn
```

Rules:
- Build a co-change map: for each commit, record which files changed together
- A file earns +2 if it co-changes with any file that already has a score > 0
- Weight by frequency: only count co-change pairs that appear in at least 2 commits (ignore one-off coincidences)

### d. Recent Modification (weight: 1)

Files modified within the last 7 days score +1.

Command:

```sh
git log --since="7 days ago" --name-only --format='' | sort -u
```

This captures files that are actively being worked on, making them more likely to be relevant to the current story.

### e. Test Coverage (weight: 1)

When a source file is relevant (score > 0), its corresponding test file scores +1.

Path mapping patterns:
- `src/foo.ts` → `tests/foo.test.ts`
- `src/foo.ts` → `src/foo.test.ts`
- `src/foo.ts` → `src/__tests__/foo.test.ts`
- `lib/foo.py` → `tests/test_foo.py`
- `pkg/foo/bar.go` → `pkg/foo/bar_test.go`

Apply the first pattern that resolves to an existing file.

### f. Pattern Match (weight: 1)

Files matching structural patterns recorded in the project DNA score +1.

Examples:
- DNA says routes live in `src/routes/*.ts` → include all route files for API stories
- DNA says config lives in `config/*.yaml` → include config files for infrastructure stories

Rules:
- Extract patterns from the project DNA document
- Match patterns against story keywords (e.g., story about "API endpoint" triggers route patterns)
- Only apply patterns that are semantically related to the story topic

---

## Scoring Algorithm

1. Initialize all file scores to 0.
2. Apply signals in order: Name Match, Import Graph, Git Proximity, Recent Modification, Test Coverage, Pattern Match.
3. Sum all signal scores per file.
4. Rank files by total score, descending.
5. Classify by score threshold:

| Score   | Classification | Action                              |
|---------|----------------|-------------------------------------|
| >= 4    | Primary        | Include in context package          |
| 2 – 3   | Supplementary  | Available on request; not auto-loaded |
| 0 – 1   | Excluded       | Omit from context entirely          |

The threshold of 4 is intentionally high enough to require at least two strong signals (e.g., name match + import graph) rather than noise from a single weak signal.

---

## Output Format

Emit a relevance analysis block in this format before building the context package:

```markdown
## Relevance Analysis: Story 03 — Add OAuth Login

### Primary (score >= 4)
- src/auth/middleware.ts (7) — name:3, import:2, git:2
- src/auth/types.ts (5) — name:3, import:2
- tests/auth/middleware.test.ts (5) — name:3, test:1, git:1

### Supplementary (score 2-3)
- src/config/auth.yaml (3) — name:3
- src/routes/login.ts (2) — git:2
```

Each line records:
- Relative file path
- Total score in parentheses
- Signal breakdown showing which signals fired and for how many points

---

## Timing and Caching

### When to run

Run relevance analysis during the **delegation phase**, before tier selection and before any file is read. Feed the primary file list into the Context Engine tier selector as the candidate set.

### Caching

- Cache results keyed on a hash of: (story file content + project file tree snapshot).
- Re-use cached results if neither the story nor the file tree has changed since the last run.
- Invalidate the cache when:
  - The story file is modified
  - A `git pull` or new commit changes the file tree
  - The user explicitly requests a refresh

Cache storage: write to `.claude/context-cache/<story-id>-relevance.json` alongside the story.

### Integration with tier selection

Pass the primary file list (score >= 4) to the tier selector as pre-filtered candidates. The tier selector then applies budget constraints (token limits) to decide how many primary files to include verbatim versus summarized. Supplementary files are noted in the context package header so the implementer agent can request them if needed.
