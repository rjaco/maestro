---
name: notify
description: "Push notifications to Slack, Discord, Telegram, and PagerDuty on build events. Provider-agnostic notification system triggered by dev-loop, ship, and watch skills."
---

# Notification System

Push status updates to external channels when significant events occur during Maestro sessions. Notifications are fire-and-forget — failures never block the dev-loop.

## Provider Architecture

| Provider | Sub-file | Method | Setup |
|----------|----------|--------|-------|
| `slack` | `provider-slack.md` | Incoming Webhook URL | Create app at api.slack.com |
| `discord` | `provider-discord.md` | Webhook URL | Channel Settings > Integrations |
| `telegram` | `provider-telegram.md` | Bot API | Create bot via @BotFather |
| `pagerduty` | `provider-pagerduty.md` | Events API v2 | Services > Integrations > Events API v2 |

## Configuration

In `.maestro/config.yaml`:

```yaml
notifications:
  enabled: true
  providers:
    slack:
      webhook_url: "https://hooks.slack.com/services/T.../B.../..."
    discord:
      webhook_url: "https://discord.com/api/webhooks/..."
    telegram:
      bot_token: "123456:ABC..."
      chat_id: "987654321"
    pagerduty:
      routing_key: null
      severity_map:
        qa_rejection: warning
        self_heal_failure: error
        test_regression: error
        consecutive_failures: critical
  triggers:
    on_story_complete: true
    on_feature_complete: true
    on_qa_rejection: true
    on_self_heal_failure: true
    on_test_regression: true
```

Only configure the providers you want. Unconfigured providers are silently skipped.

## Event Types

| Event | Trigger Point | Urgency |
|-------|---------------|---------|
| `story_complete` | dev-loop CHECKPOINT | Low |
| `feature_complete` | maestro.md Step 12 | Medium |
| `qa_rejection` | dev-loop QA REVIEW (rejected) | Medium |
| `self_heal_failure` | dev-loop SELF-HEAL (3x failed) | High |
| `test_regression` | watch/awareness check | High |
| `session_paused` | status.md pause | Low |
| `session_aborted` | status.md abort | Medium |
| `ship_complete` | ship.md PR created | Medium |

## Message Format

Each event produces a structured message:

```
[Maestro] Story 3/5 complete: API Routes

  Status    QA approved (1st attempt)
  Commit    feat(api): add user routes
  Cost      $0.95 (story) / $2.40 (total)
  Next      Story 4: Frontend components

  Project: my-project | Mode: checkpoint
```

## Operations

### send(event_type, data)

Called by skills/commands when a notification-worthy event occurs.

1. Read `.maestro/config.yaml` notifications section
2. If `notifications.enabled` is false, return silently
3. Check if `triggers.[event_type]` is true
4. For each configured provider with a non-null URL/token:
   - Format the message using the provider's template
   - Dispatch the notification via bash curl
   - Log success/failure to `.maestro/logs/notifications.log`
5. Never throw or block — all errors are logged and swallowed

### format_message(event_type, data)

Format a notification message based on event type:

**story_complete:**
```
[Maestro] Story {N}/{total}: {title}
Status: {qa_result} | Cost: ${cost} | Next: {next_title}
```

**feature_complete:**
```
[Maestro] Feature complete: {feature_name}
Stories: {completed}/{total} | Cost: ${total_cost} | Time: {duration}
QA first-pass: {rate}% | Trust: {level}
```

**qa_rejection:**
```
[Maestro] QA Rejected: {story_title} (attempt {N}/{max})
Issue: {rejection_reason}
Action: Re-implementing with feedback
```

**self_heal_failure:**
```
[Maestro] Self-heal FAILED: {story_title} (3/3 attempts)
Error: {error_summary}
Action: Session PAUSED — manual intervention needed
```

**test_regression:**
```
[Maestro] Regression detected
Failing: {test_name} in {file}
Previously: passing | Now: {error}
Action: Logged to .maestro/notes.md
```

## Integration Points

### In dev-loop/SKILL.md

At CHECKPOINT phase:
```
if config.notifications.enabled:
    if story completed successfully:
        notify.send("story_complete", {title, qa_result, cost, next_title})
    if QA rejected:
        notify.send("qa_rejection", {title, attempt, reason})
    if self-heal failed:
        notify.send("self_heal_failure", {title, error})
```

### In maestro.md (Step 12)

```
if config.notifications.enabled:
    notify.send("feature_complete", {feature, stories, cost, duration, qa_rate})
```

### In ship/SKILL.md

```
if config.notifications.enabled:
    notify.send("ship_complete", {pr_url, feature, stories})
```

### In watch/SKILL.md

```
if config.notifications.enabled:
    notify.send("test_regression", {test, file, error})
```

## Error Handling

- Webhook URL returns non-2xx → log warning, continue
- Network timeout (5s) → log warning, continue
- Provider not configured → skip silently
- Invalid config → log once per session, disable provider
- Never retry failed notifications — they're informational, not critical

## Notification Levels

Each channel can be configured to receive only notifications at or above a specified importance level. This prevents low-signal channels (e.g., a work Slack) from receiving verbose chatter while keeping a personal Telegram fully informed.

### Configuration

```yaml
# In .maestro/config.yaml
notifications:
  enabled: true
  default_level: all        # all | important | critical | none
  per_channel:
    telegram:
      level: all            # receive everything
    slack:
      level: important      # spending, errors, completions
    email:
      level: critical       # failures, over-budget, security only
  providers:
    # ... existing provider config ...
```

### Level Definitions

| Level | Events included |
|-------|----------------|
| `all` | Every action, status update, and notification |
| `important` | Spending, errors, completions, milestones, approvals needed |
| `critical` | Failures, over-budget, security alerts |
| `none` | Silent (actions still logged) |

Levels are ordered by severity: `none < all < important < critical`. A channel configured at `important` receives `important` and `critical` events but not `all`-only events.

### Event-to-Level Mapping

| Event | Level |
|-------|-------|
| `action_started` | all |
| `action_completed` | all |
| `action_auto_approved` | all |
| `action_user_approved` | important |
| `action_denied` | important |
| `action_failed` | critical |
| `spending_alert` | important |
| `spending_limit_reached` | critical |
| `milestone_complete` | important |
| `story_complete` | all |
| `approval_needed` | important |
| `security_alert` | critical |

### Filtering Logic

Before sending any notification to a channel, apply this check:

```
level_order = { all: 0, important: 1, critical: 2, none: 99 }

channel_level = per_channel[channel].level ?? default_level ?? "all"
event_level   = EVENT_LEVEL_MAP[event_type]

if level_order[event_level] >= level_order[channel_level]:
    send to channel
else:
    skip silently (still log to .maestro/logs/notifications.log)
```

A channel set to `none` never receives notifications (but the event is still logged). A channel set to `all` receives every event. Unknown event types default to `all` level so they are never silently dropped.
