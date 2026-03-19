# Opus Roadmap — Quality Refinement: Anthropic-Grade Polish

## Quality Refinement (active)

| Milestone | Stories | Status | Focus |
|-----------|---------|--------|-------|
| QR-M1 | 4 | executing | Critical data integrity fixes |
| QR-M2 | 3 | pending | Shell script security hardening |
| QR-M3 | 3 | pending | Consistency & polish |

**Total: 10 stories across 3 milestones**

---

## QR-M1: Critical Data Integrity Fixes
Fix all critical blockers — merge conflicts, duplicate JSON keys, metadata inconsistencies.
- S1: Resolve merge conflict markers in all 6 agent files + mirror
- S2: Fix hooks.json duplicate PreToolUse key
- S3: Reconcile author/owner metadata across plugin files
- S4: Update DNA file with accurate counts

## QR-M2: Shell Script Security Hardening
Fix all HIGH/MEDIUM security issues in shell scripts.
- S5: Fix unsafe sed/JSON patterns in opus-daemon.sh and notify.sh
- S6: Fix missing safety flags and temp file handling
- S7: Fix injection risks in security-drift-check.sh, telegram-send.sh, audio-alert.sh

## QR-M3: Consistency & Polish
Standardize formats, clean up orphaned files, expand minimal content.
- S8: Standardize command allowed-tools format
- S9: Clean up orphaned files and worktrees
- S10: Expand minimal agent definitions and verify completeness

---

## Previous Waves (complete)

### Wave 7 (complete)
| Milestone | Stories | Status | Focus |
|-----------|---------|--------|-------|
| W7-M1 | 6 | complete | Hook coverage & zero-code wins |
| W7-M2 | 4 | complete | Quality & testing |
| W7-M3 | 4 | complete | Developer experience polish |

### Wave 6 (complete)
| Milestone | Stories | Status | Focus |
|-----------|---------|--------|-------|
| M1 | 4 | complete | Full-auto reliability |
| M2 | 3 | complete | Multi-instance coordination |
| M3 | 3 | complete | Communication channels |
| M4 | 3 | complete | Enhanced SOUL & personality |
| M5 | 4 | complete | Ruflo feature adoption |
| M6 | 3 | complete | OpenClaw-inspired enhancements |
