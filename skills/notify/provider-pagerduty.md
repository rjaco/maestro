---
name: notify-provider-pagerduty
description: "PagerDuty notification provider. Sends alerts via Events API v2 using bash curl with severity mapping and incident resolution support."
---

# Notification Provider: PagerDuty

Sends Maestro alerts to PagerDuty via Events API v2. Supports severity-mapped triggers and automatic incident resolution when previously-failing builds recover.

## Prerequisites

1. In PagerDuty: Services > (your service) > Integrations > Add Integration > Events API v2
2. Copy the integration key (routing key) to `.maestro/config.yaml`:

```yaml
notifications:
  providers:
    pagerduty:
      routing_key: "your32characterroutingkeyhere00"
      severity_map:
        qa_rejection: warning
        self_heal_failure: error
        test_regression: error
        consecutive_failures: critical
        story_complete: info
        feature_complete: info
```

`story_complete` notifications are off by default. Enable them by adding `on_story_complete: true` to `notifications.triggers`.

## Severity Mapping

| Maestro Event | PagerDuty Severity | Default |
|---------------|--------------------|---------|
| `qa_rejection` | `warning` | on |
| `self_heal_failure` | `error` | on |
| `test_regression` | `error` | on |
| `consecutive_failures` | `critical` | on |
| `story_complete` | `info` | off |
| `feature_complete` | `info` | on |

Override any mapping in `severity_map` to adjust alert urgency for your team's on-call policy.

## Payload Format

All events use the PagerDuty Events API v2 enqueue endpoint: `https://events.pagerduty.com/v2/enqueue`

Summary format: `[Maestro] {event_type}: {details}`

### Sending a trigger event

```bash
curl -s -X POST "https://events.pagerduty.com/v2/enqueue" \
  -H "Content-Type: application/json" \
  -d '{
    "routing_key": "'"${ROUTING_KEY}"'",
    "event_action": "trigger",
    "dedup_key": "'"${DEDUP_KEY}"'",
    "payload": {
      "summary": "[Maestro] '"${EVENT_TYPE}"': '"${SUMMARY}"'",
      "severity": "'"${SEVERITY}"'",
      "source": "'"${PROJECT}"'",
      "component": "'"${STORY_OR_FEATURE}"'",
      "custom_details": {
        "cost": "'"${COST}"'",
        "tokens": "'"${TOKENS}"'",
        "story_count": "'"${STORY_COUNT}"'",
        "event_type": "'"${EVENT_TYPE}"'"
      }
    }
  }'
```

### Dedup key format

```
maestro-{feature_name}-{event_type}
```

Example: `maestro-user-auth-self_heal_failure`

This ensures repeated failures for the same feature/event are deduplicated into a single PagerDuty incident rather than flooding the on-call queue.

## Event-Specific Payloads

### qa_rejection (warning)

```bash
DEDUP_KEY="maestro-${FEATURE_NAME}-qa_rejection"
SUMMARY="${STORY_TITLE} (attempt ${ATTEMPT}/${MAX}): ${REASON}"

curl -s -X POST "https://events.pagerduty.com/v2/enqueue" \
  -H "Content-Type: application/json" \
  -d '{
    "routing_key": "'"${ROUTING_KEY}"'",
    "event_action": "trigger",
    "dedup_key": "'"${DEDUP_KEY}"'",
    "payload": {
      "summary": "[Maestro] qa_rejection: '"${SUMMARY}"'",
      "severity": "warning",
      "source": "'"${PROJECT}"'",
      "component": "'"${STORY_TITLE}"'",
      "custom_details": {
        "attempt": "'"${ATTEMPT}"'",
        "max_attempts": "'"${MAX}"'",
        "reason": "'"${REASON}"'",
        "cost": "'"${COST}"'"
      }
    }
  }'
```

### self_heal_failure (error)

```bash
DEDUP_KEY="maestro-${FEATURE_NAME}-self_heal_failure"
SUMMARY="${STORY_TITLE} — 3/3 self-heal attempts failed"

curl -s -X POST "https://events.pagerduty.com/v2/enqueue" \
  -H "Content-Type: application/json" \
  -d '{
    "routing_key": "'"${ROUTING_KEY}"'",
    "event_action": "trigger",
    "dedup_key": "'"${DEDUP_KEY}"'",
    "payload": {
      "summary": "[Maestro] self_heal_failure: '"${SUMMARY}"'",
      "severity": "error",
      "source": "'"${PROJECT}"'",
      "component": "'"${STORY_TITLE}"'",
      "custom_details": {
        "error_summary": "'"${ERROR_SUMMARY}"'",
        "action": "Session paused — manual intervention needed",
        "cost": "'"${COST}"'",
        "tokens": "'"${TOKENS}"'"
      }
    }
  }'
```

### test_regression (error)

```bash
DEDUP_KEY="maestro-${FEATURE_NAME}-test_regression"
SUMMARY="${TEST_NAME} in ${FILE}: was passing, now ${ERROR}"

curl -s -X POST "https://events.pagerduty.com/v2/enqueue" \
  -H "Content-Type: application/json" \
  -d '{
    "routing_key": "'"${ROUTING_KEY}"'",
    "event_action": "trigger",
    "dedup_key": "'"${DEDUP_KEY}"'",
    "payload": {
      "summary": "[Maestro] test_regression: '"${SUMMARY}"'",
      "severity": "error",
      "source": "'"${PROJECT}"'",
      "component": "'"${FEATURE_NAME}"'",
      "custom_details": {
        "test_name": "'"${TEST_NAME}"'",
        "file": "'"${FILE}"'",
        "error": "'"${ERROR}"'"
      }
    }
  }'
```

### consecutive_failures (critical)

```bash
DEDUP_KEY="maestro-${FEATURE_NAME}-consecutive_failures"
SUMMARY="${FEATURE_NAME} — ${FAILURE_COUNT} consecutive story failures"

curl -s -X POST "https://events.pagerduty.com/v2/enqueue" \
  -H "Content-Type: application/json" \
  -d '{
    "routing_key": "'"${ROUTING_KEY}"'",
    "event_action": "trigger",
    "dedup_key": "'"${DEDUP_KEY}"'",
    "payload": {
      "summary": "[Maestro] consecutive_failures: '"${SUMMARY}"'",
      "severity": "critical",
      "source": "'"${PROJECT}"'",
      "component": "'"${FEATURE_NAME}"'",
      "custom_details": {
        "failure_count": "'"${FAILURE_COUNT}"'",
        "last_error": "'"${LAST_ERROR}"'",
        "story_count": "'"${STORY_COUNT}"'",
        "cost": "'"${COST}"'"
      }
    }
  }'
```

### feature_complete (info)

```bash
DEDUP_KEY="maestro-${FEATURE_NAME}-feature_complete"
SUMMARY="${FEATURE_NAME} — ${COMPLETED}/${TOTAL} stories done in ${DURATION}"

curl -s -X POST "https://events.pagerduty.com/v2/enqueue" \
  -H "Content-Type: application/json" \
  -d '{
    "routing_key": "'"${ROUTING_KEY}"'",
    "event_action": "trigger",
    "dedup_key": "'"${DEDUP_KEY}"'",
    "payload": {
      "summary": "[Maestro] feature_complete: '"${SUMMARY}"'",
      "severity": "info",
      "source": "'"${PROJECT}"'",
      "component": "'"${FEATURE_NAME}"'",
      "custom_details": {
        "stories_completed": "'"${COMPLETED}"'",
        "stories_total": "'"${TOTAL}"'",
        "total_cost": "$'"${COST}"'",
        "tokens": "'"${TOKENS}"'",
        "duration": "'"${DURATION}"'",
        "qa_first_pass_rate": "'"${QA_RATE}"'%"
      }
    }
  }'
```

### story_complete (info, off by default)

```bash
DEDUP_KEY="maestro-${FEATURE_NAME}-story_complete-${STORY_N}"
SUMMARY="${STORY_TITLE} (${STORY_N}/${TOTAL}) — ${QA_RESULT}"

curl -s -X POST "https://events.pagerduty.com/v2/enqueue" \
  -H "Content-Type: application/json" \
  -d '{
    "routing_key": "'"${ROUTING_KEY}"'",
    "event_action": "trigger",
    "dedup_key": "'"${DEDUP_KEY}"'",
    "payload": {
      "summary": "[Maestro] story_complete: '"${SUMMARY}"'",
      "severity": "info",
      "source": "'"${PROJECT}"'",
      "component": "'"${STORY_TITLE}"'",
      "custom_details": {
        "story_number": "'"${STORY_N}"'",
        "total_stories": "'"${TOTAL}"'",
        "qa_result": "'"${QA_RESULT}"'",
        "cost": "$'"${COST}"'",
        "next_story": "'"${NEXT_TITLE}"'"
      }
    }
  }'
```

## Incident Resolution

When a build recovers after a previous failure, send a resolve event using the same `dedup_key` as the original trigger. PagerDuty will auto-resolve the open incident.

```bash
# Resolve a previously-triggered incident
curl -s -X POST "https://events.pagerduty.com/v2/enqueue" \
  -H "Content-Type: application/json" \
  -d '{
    "routing_key": "'"${ROUTING_KEY}"'",
    "event_action": "resolve",
    "dedup_key": "'"${DEDUP_KEY}"'"
  }'
```

### When to resolve

| Trigger event | Resolution condition |
|---------------|----------------------|
| `self_heal_failure` | Story subsequently passes QA |
| `test_regression` | Failing test returns to green |
| `consecutive_failures` | Next story in feature completes successfully |
| `qa_rejection` | Story passes QA on a later attempt |

Example — resolving a self-heal failure after the story later passes:

```bash
DEDUP_KEY="maestro-${FEATURE_NAME}-self_heal_failure"

curl -s -X POST "https://events.pagerduty.com/v2/enqueue" \
  -H "Content-Type: application/json" \
  -d '{
    "routing_key": "'"${ROUTING_KEY}"'",
    "event_action": "resolve",
    "dedup_key": "'"${DEDUP_KEY}"'"
  }'
```

## Testing

```bash
# Send a test alert (will open a low-urgency incident)
curl -s -X POST "https://events.pagerduty.com/v2/enqueue" \
  -H "Content-Type: application/json" \
  -d '{
    "routing_key": "'"${ROUTING_KEY}"'",
    "event_action": "trigger",
    "dedup_key": "maestro-test-connectivity",
    "payload": {
      "summary": "[Maestro] Test alert — PagerDuty is configured correctly.",
      "severity": "info",
      "source": "maestro-test"
    }
  }'

# Then resolve it immediately
curl -s -X POST "https://events.pagerduty.com/v2/enqueue" \
  -H "Content-Type: application/json" \
  -d '{
    "routing_key": "'"${ROUTING_KEY}"'",
    "event_action": "resolve",
    "dedup_key": "maestro-test-connectivity"
  }'
```

## Error Handling

- 202 Accepted → success (PagerDuty queues the event asynchronously)
- 400 → invalid payload (check JSON structure and routing key format)
- 429 → rate limited (back off; not expected under normal Maestro usage)
- Timeout (5s) → network issue, skip and log
- Never retry failed notifications — they are informational, not critical
