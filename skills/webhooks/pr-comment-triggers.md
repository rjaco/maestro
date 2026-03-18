---
name: webhooks-pr-comment-triggers
description: "PR comment command triggers. Parses @maestro commands from PR comments and routes to Maestro skills."
---

# PR Comment Triggers

When a PR comment contains an `@maestro` command, Maestro picks up the event and acts on it. This enables GitHub-native interaction without leaving the PR workflow.

## Command Format

```
@maestro <command> [args]
```

Commands are case-insensitive. Only the first `@maestro` line in a comment is processed.

## Supported Commands

| Command | Args | Maestro Action | Skill Invoked |
|---------|------|----------------|---------------|
| `@maestro build` | — | Trigger CI build for PR branch | `ci-watch` (monitor mode) |
| `@maestro review` | — | Run multi-agent code review on PR diff | `multi-review` |
| `@maestro fix` | `[issue description]` | Auto-fix issues found in review or CI | `dev-loop` (self-heal phase) |
| `@maestro status` | — | Reply with current build/review status | `status` (read state) |
| `@maestro test` | `[test pattern]` | Run tests for the PR branch | `dev-loop` (validate phase) |
| `@maestro plan` | `"feature description"` | Decompose the PR into stories | `decompose` |
| `@maestro help` | — | Reply with available commands | (self-contained) |

## Parsing Logic

Extract command from comment body:

```
1. Read comment body
2. Find first line matching: /^\s*@maestro\s+(\w+)\s*(.*)/i
3. Extract:
   - command = capture group 1 (lowercase)
   - args = capture group 2 (trimmed, may be empty)
4. If no match: skip — not a Maestro command
```

## Authorization

Only process commands from authorized users to prevent abuse.

**Authorization check:**
1. Extract comment author login from event payload
2. Check if author has `write` or `admin` permission on the repo:
   ```bash
   gh api repos/{owner}/{repo}/collaborators/{author}/permission --jq '.permission'
   ```
3. Accepted permissions: `admin`, `maintain`, `write`
4. Rejected: `triage`, `read`, or non-collaborators

**If unauthorized:**
- Log the attempt to `.maestro/webhooks/log.md`
- Do not reply to the comment
- Do not execute any action

## Event Detection

### Via Queue File

External webhook receiver writes `issue_comment` events to queue:

```json
{
  "id": "evt_042",
  "source": "github",
  "type": "issue_comment.created",
  "timestamp": "2026-03-18T12:00:00Z",
  "payload": {
    "action": "created",
    "issue_number": 42,
    "is_pull_request": true,
    "comment_body": "@maestro review",
    "comment_author": "rodrigo",
    "pr_branch": "feat/auth",
    "pr_base": "main"
  },
  "processed": false
}
```

### Via gh CLI Polling

```bash
# Poll recent PR comments for @maestro commands
gh api repos/{owner}/{repo}/issues/comments \
  --paginate --limit 20 \
  --jq '[.[] | select(.body | test("@maestro"; "i")) | select(.created_at > "LAST_POLL_TIME")] |
    map({
      id: .id,
      issue_number: .issue_url | split("/") | last,
      body: .body,
      author: .user.login,
      created_at: .created_at
    })'
```

## Command Routing

When a valid, authorized command is detected:

1. **Log** the command to `.maestro/webhooks/log.md`:
   ```
   [2026-03-18T12:00:00Z] PR #42 | @rodrigo | @maestro review | status: processing
   ```

2. **Checkout** the PR branch (if needed for build/test/fix):
   ```bash
   gh pr checkout 42
   ```

3. **Invoke** the mapped Maestro skill with PR context:
   - Pass PR number, branch, base branch, diff as context
   - Run in the PR's branch context

4. **Respond** to the PR comment (if GitHub token has write access):
   ```bash
   gh pr comment 42 --body "Maestro received: \`@maestro review\`. Starting multi-agent code review..."
   ```

5. **Post results** as a follow-up PR comment when complete:
   ```bash
   gh pr comment 42 --body "## Maestro Review Complete\n\n[review summary]"
   ```

## Integration Points

- **ci-watch**: `@maestro build` triggers CI monitoring for the PR branch
- **multi-review**: `@maestro review` dispatches correctness + security + performance reviewers
- **dev-loop**: `@maestro fix` enters self-heal phase for the PR
- **notify**: all command receipts and completions trigger notifications
- **webhooks/SKILL.md**: PR comment events added to the routing table

## Rate Limiting

- Max 5 commands per PR per hour (prevent infinite loops)
- Max 1 concurrent `fix` or `build` command per PR
- Duplicate commands within 60 seconds are silently ignored
- Track command counts in `.maestro/webhooks/rate-limits.json`
