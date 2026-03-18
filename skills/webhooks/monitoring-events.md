---
name: webhooks-monitoring-events
description: "Monitoring and alerting event processing. Maps events from Sentry, Datadog, UptimeRobot, PagerDuty, and generic sources to Maestro actions."
---

# Monitoring Event Processing

Handle monitoring and alerting webhook events from common observability platforms. Routes alerts to notifications, awareness logging, and automatic fix story creation.

## Supported Sources

### Sentry

**Events:**

| Event | Payload Fields | Maestro Action |
|-------|---------------|----------------|
| `error.created` | `title`, `culprit`, `level`, `url` | Notify (error), create fix story |
| `issue.created` | `title`, `culprit`, `firstSeen` | Notify, log to awareness |
| `issue.resolved` | `title`, `resolvedAt` | Notify (info), resolve incident |
| `issue.regression` | `title`, `culprit` | Notify (alert), create fix story |

**Fix story creation:** When a Sentry error is received, auto-create a story:
```markdown
## Fix: [Sentry error title]

**Source:** Sentry error [url]
**Culprit:** [culprit file/function]
**Level:** [error/warning/fatal]

### Acceptance Criteria
- [ ] Error no longer reproduces
- [ ] Root cause documented
- [ ] Test added to prevent regression
```

### Datadog

**Events:**

| Event | Payload Fields | Maestro Action |
|-------|---------------|----------------|
| `alert.triggered` | `title`, `priority`, `tags`, `url` | Notify (severity from priority), log to awareness |
| `alert.recovered` | `title`, `tags` | Notify (info), resolve in awareness |
| `alert.no_data` | `title`, `monitor_id` | Notify (warning), log |

**Priority mapping:**
| Datadog Priority | Maestro Severity | Notification Level |
|-----------------|-----------------|-------------------|
| P1 (Critical) | critical | Immediate alert |
| P2 (High) | error | Alert |
| P3 (Medium) | warning | Standard notification |
| P4 (Low) | info | Log only |

### UptimeRobot

**Events:**

| Event | Payload Fields | Maestro Action |
|-------|---------------|----------------|
| `monitor.down` | `monitorURL`, `alertDetails`, `monitorFriendlyName` | Critical notification, log incident |
| `monitor.up` | `monitorURL`, `alertDuration`, `monitorFriendlyName` | Resolve notification, log recovery |

**Downtime tracking:** On `monitor.down`, start tracking:
```
incidents:
  - url: https://my-app.com
    down_at: 2026-03-18T12:00:00Z
    status: down
```
On `monitor.up`, resolve and compute duration.

### PagerDuty (Inbound)

**Events:**

| Event | Payload Fields | Maestro Action |
|-------|---------------|----------------|
| `incident.triggered` | `title`, `urgency`, `service` | Notify (critical), log incident, create fix story if code-related |
| `incident.resolved` | `title`, `service` | Notify (info), resolve in awareness |
| `incident.acknowledged` | `title`, `assignee` | Log acknowledgment |

Note: This is *inbound* PagerDuty events (PagerDuty notifying Maestro). For *outbound* (Maestro sending to PagerDuty), see `notify/provider-pagerduty.md`.

### Generic Webhooks

For any monitoring source not explicitly supported:

```json
{
  "source": "monitoring",
  "type": "alert.triggered",
  "payload": {
    "title": "Alert description",
    "severity": "error",
    "service": "api-server",
    "url": "https://monitoring.example.com/alert/123",
    "details": "Free-form details"
  }
}
```

**Severity mapping for generic events:**
| Severity Field | Maestro Action |
|---------------|----------------|
| `critical` or `fatal` | Critical notification + create fix story |
| `error` or `high` | Alert notification + log to awareness |
| `warning` or `medium` | Standard notification |
| `info` or `low` | Log only |

## Integration with Awareness Skill

All monitoring events are logged to the awareness skill for trend tracking:

1. **Incident log:** `.maestro/logs/incidents.md` — running log of all monitoring events
2. **Active incidents:** tracked in `.maestro/state.local.md` under `incidents:` key
3. **Trend analysis:** awareness skill checks incident frequency during heartbeat checks
4. **Correlation:** if errors spike after a deploy, awareness flags the correlation

## Auto-Fix Story Creation

When severity is `error` or higher and the error includes a code reference (file path, stack trace, culprit):

1. Parse the error for affected file/function
2. Create a fix story in `.maestro/stories/`:
   - Title: "Fix: [error title]"
   - Type: bugfix
   - Priority: maps from severity
   - Acceptance criteria: error resolved + test added
3. Optionally auto-assign to dev-loop if in full_auto mode

## Configuration

```yaml
webhooks:
  routes:
    monitoring:
      sources: [sentry, datadog, uptimerobot, pagerduty]
      auto_create_fix_stories: true
      severity_threshold: error  # only create stories for error+
      incident_tracking: true
```
