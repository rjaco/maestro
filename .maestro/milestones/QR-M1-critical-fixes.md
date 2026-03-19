# QR-M1: Critical Data Integrity Fixes

## Focus
Fix all critical blockers: merge conflicts, duplicate JSON keys, metadata inconsistencies.

## Stories

### S1: Resolve merge conflict markers in all 6 agent files
- Fix agents/implementer.md, qa-reviewer.md, fixer.md, strategist.md, researcher.md, proactive.md
- Reconcile effort + maxTurns fields (keep BOTH — they serve different purposes)
- Sync fixes to plugins/maestro/agents/ mirror
- Acceptance: Zero `<<<<<<<` markers in entire codebase

### S2: Fix hooks.json duplicate PreToolUse key
- Merge both PreToolUse blocks into a single entry with all matchers
- Verify all hooks (branch-guard, delegation-hook) are registered
- Acceptance: `python3 -c "import json; json.load(open('hooks/hooks.json'))"` succeeds with all hooks present

### S3: Reconcile author/owner metadata across plugin files
- Standardize author info in plugin.json and marketplace.json
- Ensure consistent naming and URLs
- Acceptance: Consistent author/owner across all manifest files

### S4: Update DNA file with accurate counts
- Count actual skills, commands, profiles, templates, hooks
- Update .maestro/dna.md with correct numbers
- Acceptance: All counts in dna.md match `find` results
