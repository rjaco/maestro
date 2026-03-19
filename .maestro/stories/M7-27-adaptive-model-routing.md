---
id: M7-27
slug: adaptive-model-routing
title: "Adaptive model routing — historical performance tracking per task type"
type: enhancement
depends_on: []
parallel_safe: true
complexity: medium
model_recommendation: sonnet
---

## Acceptance Criteria

1. Enhanced `skills/model-router/SKILL.md` with:
   - **Historical tracking**: Record model performance per task type in `.maestro/model-performance.md`
   - **Metrics tracked**: Success rate, tokens used, QA pass rate, time to complete
   - **Task types**: implementation, review, planning, research, documentation, testing
   - **Auto-adjustment**: If haiku consistently fails at task type X, auto-upgrade to sonnet for X
2. Performance log format:
   ```markdown
   ## Model Performance
   | Task Type | Model | Success Rate | Avg Tokens | QA Pass |
   |-----------|-------|-------------|------------|---------|
   | implementation | sonnet | 85% | 12K | 80% |
   | review | haiku | 92% | 3K | 95% |
   ```
3. After 10 samples per task-type/model combo, recommendations become stable
4. User can override via `/maestro model` command
5. Mirror: skill in both root and plugins/maestro/

## Context for Implementer

Read the current `skills/model-router/SKILL.md` first. It has a 10-dimension scoring system. Add historical performance tracking on top.

The idea: instead of just scoring tasks statically, track what actually happened when we used each model for each task type. Over time, the router learns which models work best for which tasks in THIS project.

After each agent dispatch:
1. Record: task_type, model_used, success (DONE/BLOCKED/NEEDS_CONTEXT), tokens_used, qa_result
2. When routing the next task: look up historical performance for that task type
3. If historical data shows model X has < 60% success for this task type, upgrade

Reference: skills/model-router/SKILL.md (current)
Reference: skills/delegation/SKILL.md for dispatch context
Reference: skills/token-ledger/SKILL.md for token tracking
