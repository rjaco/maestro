---
name: git-craft
description: "Create documentation-quality git commits that serve as the project's implementation record. Use after a story passes QA review."
---

# git-craft

## Purpose

Each commit tells the full story of what was built. Months from now, `git log` should read like a project journal — not a stream of "fix stuff" messages.

## Commit Format

```
type(story-NN): short description

- What was created/modified (specific files)
- Tests: N passing (what they cover)
- Acceptance criteria: AC1 check, AC2 check, AC3 check

Story: .maestro/stories/NN-slug.md
Tokens: NNNN (if cost tracking enabled)
```

## Commit Types

| Type | When to use |
|------|-------------|
| `feat` | New functionality visible to users or downstream code |
| `fix` | Bug fix — something was broken, now it works |
| `refactor` | Internal restructuring with no behavior change |
| `test` | Adding or updating tests only |
| `docs` | Documentation changes only |
| `chore` | Build, CI, dependency updates, housekeeping |

## Scope

- **Story scope:** `story-NN` (e.g., `feat(story-03): add price comparison table`)
- **Milestone scope:** `milestone-NN` (e.g., `chore(milestone-01): update roadmap after MVP`)

## Body Rules

- Concrete facts only. No fluff, no "improved the system," no adjectives.
- List specific files created or modified.
- State test count and what they cover.
- Map each acceptance criterion to its verification status.
- If cost tracking is enabled, include token count from the token-ledger.

## Staging Rules

- Stage only files related to the completed story.
- **Never stage:** `.env`, credentials, secrets, `node_modules`, `.maestro/state.local.md`
- Prefer `git add <specific-files>` over `git add .` or `git add -A`.
- Review the diff before committing — no accidental inclusions.

## Commit Message Formatting

Always use HEREDOC format for multi-line commit messages:

```bash
git commit -m "$(cat <<'EOF'
feat(story-07): implement vehicle price comparison table

- Created src/components/comparison/PriceTable.tsx
- Modified src/app/comparar/[slugs]/page.tsx to integrate table
- Tests: 4 passing (render, empty state, sorting, mobile layout)
- Acceptance criteria: AC1 side-by-side layout, AC2 price sorting, AC3 responsive

Story: .maestro/stories/07-price-comparison.md
Tokens: 12400
EOF
)"
```

## Post-Commit

After a successful commit, update `.maestro/state.local.md` with:
- Story ID marked as completed
- Completion timestamp
- Any concerns flagged during QA review
