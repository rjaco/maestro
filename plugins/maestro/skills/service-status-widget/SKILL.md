---
name: service-status-widget
description: "Reusable service connection status widget. Reads .maestro/services.yaml and displays each service with type, status indicator, and health detail. Embeddable in dashboard or callable standalone."
---

# service-status-widget

## Purpose

Display the current connection status of all configured services. Usable as a standalone command or embedded inside other views (dashboard, status, doctor). Always reads live data from `.maestro/services.yaml`.

## Data Source

Read `.maestro/services.yaml`. Each service entry contains:
- `name` — display name
- `type` — category (cloud, development, communication, payment, domain)
- `status` — `connected`, `error`, or `disconnected`
- `health_detail` — optional short string describing current health state
- `capabilities` — list of capability strings

If `services.yaml` does not exist, output:
```
(i) No services configured. Run /maestro connect <service> to add one.
```

## Sort Order

Display services in this order:
1. `connected` services first
2. `error` services next
3. `disconnected` services last

Within each group, preserve the order from `services.yaml`.

## Status Indicators

| Status | Indicator |
|--------|-----------|
| connected | `(ok)` |
| error | `(!)` |
| disconnected | `--` |

## Standalone Output

When invoked directly (e.g., `/maestro services status`), render:

```
+---------------------------------------------+
| Service Connections                         |
+---------------------------------------------+
  Service        Type           Status     Health
  ───────────────────────────────────────────────
  aws            cloud          (ok)       identity verified
  github         development    (ok)       gh authenticated
  telegram       communication  (ok)       bot responding
  vercel         cloud          (!)        401 Unauthorized
  cloudflare     cloud          --         not configured
  stripe         payment        --         not configured
  sendgrid       communication  --         not configured
  twilio         communication  --         not configured
  namecheap      domain         --         not configured
  slack          communication  --         not configured
  ───────────────────────────────────────────────
  3 connected  |  1 error  |  6 disconnected

  (i) Connect more: /maestro connect <service>
  (i) Run health checks: /maestro services health
```

Column alignment rules:
- `Service` column: 14 chars wide, left-aligned
- `Type` column: 14 chars wide, left-aligned
- `Status` column: 10 chars wide, left-aligned
- `Health` column: remainder, left-aligned, truncated at 40 chars if needed

## Health Detail Field

Populate the `Health` column as follows:
- `connected`: use `health_detail` from services.yaml if present; otherwise show `connected`
- `error`: use `health_detail` if present; otherwise show the error string or `check failed`
- `disconnected`: show `not configured`

## Summary Line

Always include the summary line after the separator:
```
  N connected  |  N error  |  N disconnected
```

Count each category from all entries in services.yaml.

## Embedded Mode

When embedded in the dashboard or another widget, render the compact form (no outer box, no footer tips):

```
  Services:
    (ok) aws         connected    compute, storage
    (ok) github      connected    repos, issues
    (!)  vercel      error        token expired
    --   stripe      disconnected
    ────────────────────────────────────
    2 connected  |  1 error  |  1 disconnected
```

In embedded mode:
- Skip the `+---+` box header
- Skip the column header row
- Show service name, status indicator, connection state, and comma-joined capabilities (or error reason)
- Keep the summary line

## Integration

- Invoked by the `dashboard` skill for its Services section
- Invoked by `/maestro services` command for standalone display
- Invoked by the `health-score` skill for integration checks
