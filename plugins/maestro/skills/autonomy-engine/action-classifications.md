---
name: action-classifications
description: "Full reference table mapping service operations to risk tiers (T1/T2/T3) for the autonomy engine. Used by SKILL.md during action classification."
---

# Action Classification Reference

This file is the authoritative lookup table for the autonomy engine. For each service, operations are grouped by tier. When classifying an action, match the operation verb against the lists below.

## Classification Rules

```yaml
action_classifications:

  # ─── Cloud Providers ───────────────────────────────────────────────────────

  aws:
    free:             [list, describe, get, show, status, check]
    reversible_paid:  [create, start, run, launch, deploy, update, put, attach, enable]
    irreversible:     [delete, terminate, remove, destroy, detach, disable, deregister]

  gcp:
    free:             [list, describe, get, show, status]
    reversible_paid:  [create, start, deploy, update, patch, enable]
    irreversible:     [delete, remove, disable, destroy]

  azure:
    free:             [list, show, get, status]
    reversible_paid:  [create, start, deploy, update, set]
    irreversible:     [delete, remove, destroy]

  # ─── CDN / DNS / Hosting ───────────────────────────────────────────────────

  cloudflare:
    free:             [list, show, get]
    reversible_paid:  [create, update, deploy, enable, disable]
    irreversible:     [delete, purge]

  vercel:
    free:             [list, inspect, whoami]
    reversible_paid:  [deploy, "env add", "env update"]
    irreversible:     [remove, delete, "env remove"]

  netlify:
    free:             [list, status, whoami]
    reversible_paid:  [deploy, create, update]
    irreversible:     [delete, remove]

  # ─── Domain Registrars ─────────────────────────────────────────────────────

  namecheap:
    free:             [check, getList, getInfo, getTldList]
    reversible_paid:  [setDNS, setHosts, addRegistrant]
    irreversible:     [create, purchase, transfer, renew]

  godaddy:
    free:             [list, get, check, suggest]
    reversible_paid:  [setDNS, update]
    irreversible:     [purchase, transfer, renew, delete]

  # ─── Communication ─────────────────────────────────────────────────────────

  sendgrid:
    free:             [get, list, stats, validate]
    reversible_paid:  ["create template", "create contact", "add contact", "update template"]
    irreversible:     ["send email", "send", delete]

  mailgun:
    free:             [list, get, validate, stats]
    reversible_paid:  ["create template", "add route", "create list"]
    irreversible:     ["send email", send, delete, remove]

  twilio:
    free:             [list, fetch, get, lookup]
    reversible_paid:  ["buy number", create, update]
    irreversible:     ["send sms", "make call", "release number", send, delete]

  postmark:
    free:             [get, list, stats]
    reversible_paid:  ["create template", "create stream"]
    irreversible:     [send, "send batch", delete]

  # ─── Payments ──────────────────────────────────────────────────────────────

  stripe:
    free:             [list, retrieve, balance, inspect]
    reversible_paid:  ["create product", "create price", "create customer", "create subscription", update]
    irreversible:     ["create charge", "create invoice", "send invoice", refund, delete, cancel]

  paypal:
    free:             [list, get, show]
    reversible_paid:  ["create order", "create product", update]
    irreversible:     ["capture payment", refund, delete]

  # ─── Databases ─────────────────────────────────────────────────────────────

  supabase:
    free:             [select, list, inspect, status]
    reversible_paid:  [insert, update, upsert, "create table", "create function", deploy]
    irreversible:     [delete, "drop table", "drop column", truncate, "drop function"]

  planetscale:
    free:             [list, show, status]
    reversible_paid:  [create, deploy, "open branch"]
    irreversible:     [delete, "close branch", "delete branch"]

  # ─── Monitoring / Alerting ─────────────────────────────────────────────────

  pagerduty:
    free:             [list, get, show]
    reversible_paid:  [create, update, "acknowledge incident"]
    irreversible:     [delete, "resolve incident", "trigger incident"]

  datadog:
    free:             [list, get, query, search]
    reversible_paid:  [create, update, enable]
    irreversible:     [delete, disable]

  # ─── Social Media ──────────────────────────────────────────────────────────

  twitter:
    free:             [search, "get timeline", "get profile", lookup]
    reversible_paid:  [follow, like, bookmark]
    irreversible:     [tweet, reply, dm, retweet, unfollow, delete]

  linkedin:
    free:             [search, "get profile", "get feed"]
    reversible_paid:  [connect, follow]
    irreversible:     [post, share, message, delete]

  # ─── Version Control / CI ──────────────────────────────────────────────────

  github:
    free:             [list, get, show, search, clone, fetch]
    reversible_paid:  ["create pr", "create branch", "create issue", comment, push, merge]
    irreversible:     [delete, "delete branch", "delete repo", "close issue", release]

  # ─── Browser Automation ────────────────────────────────────────────────────

  browser:
    free:             [navigate, screenshot, read, "get text", snapshot, scroll]
    reversible_paid:  ["fill form", click, hover, select, type]
    irreversible:     ["submit form", purchase, post, register, "click submit", checkout, pay]
```

## Tier Definitions (Quick Reference)

| Tier | Label | Auto-approve? | Examples |
|------|-------|--------------|---------|
| T1 | Free | Always | List EC2 instances, check DNS record, read Stripe balance, browser screenshot |
| T2 | Reversible-paid | Auto under spending limit | Deploy to Vercel, create Stripe customer, buy a Twilio number, open GitHub PR |
| T3 | Irreversible | Requires confirmation (tiered/manual) | Purchase domain, send email, post tweet, delete AWS resource, submit payment form |

## Adding New Services

When encountering a service not listed here, apply these heuristics and add the classification permanently:

1. **T1 candidates:** Any operation that only reads data, checks status, or lists resources without side effects.
2. **T2 candidates:** Operations that create or modify resources but can be undone (deleted, rolled back, or reversed) without permanent financial or reputational damage.
3. **T3 candidates:** Operations that cannot be reversed: money spent, messages sent, public posts made, resources permanently deleted.

When in doubt, escalate the tier. A T2 incorrectly treated as T3 costs one approval prompt. A T3 incorrectly treated as T1 can cause irreversible harm.
