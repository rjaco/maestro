---
name: webhooks-deploy-events
description: "Deployment event processing. Maps deploy webhooks from Vercel, Netlify, GitHub Actions, and Railway to Maestro actions."
---

# Deploy Event Processing

Handle deployment-related webhook events from common hosting platforms. Triggers notifications, state updates, and post-deploy health checks.

## Supported Platforms

### Vercel

**Events:**

| Event | Payload Fields | Maestro Action |
|-------|---------------|----------------|
| `deployment.created` | `url`, `name`, `meta.githubCommitSha` | Log to state, notify (info) |
| `deployment.succeeded` | `url`, `name`, `inspectorUrl` | Notify (success), run post-deploy checks |
| `deployment.failed` | `url`, `name`, `error` | Notify (alert), log error |
| `deployment.canceled` | `url`, `name` | Log cancellation |

**Queue format:**
```json
{
  "source": "deploy",
  "type": "deployment.succeeded",
  "payload": {
    "platform": "vercel",
    "url": "https://my-app-abc123.vercel.app",
    "commit_sha": "a1b2c3d",
    "environment": "preview",
    "project": "my-app"
  }
}
```

### Netlify

**Events:**

| Event | Payload Fields | Maestro Action |
|-------|---------------|----------------|
| `deploy_created` | `id`, `branch`, `commit_ref` | Log to state |
| `deploy_building` | `id`, `branch` | Log (informational) |
| `deploy_ready` | `id`, `url`, `deploy_ssl_url` | Notify (success), post-deploy checks |
| `deploy_failed` | `id`, `error_message`, `branch` | Notify (alert), log error |

### GitHub Actions (Deploy Workflows)

**Detection:** Workflow runs with name containing `deploy`, `release`, or `ship`.

```bash
gh run list --workflow deploy.yml --limit 5 --json databaseId,status,conclusion,headBranch,updatedAt
```

| Conclusion | Maestro Action |
|------------|----------------|
| `success` | Notify, update state, run post-deploy checks |
| `failure` | Notify (alert), log error, suggest fix |
| `cancelled` | Log cancellation |

### Railway

**Events:**

| Event | Payload Fields | Maestro Action |
|-------|---------------|----------------|
| `deploy.started` | `service`, `environment` | Log to state |
| `deploy.completed` | `service`, `environment`, `url` | Notify (success), post-deploy checks |
| `deploy.failed` | `service`, `environment`, `error` | Notify (alert), log error |

## Post-Deploy Actions

When a deployment succeeds, trigger in sequence:

1. **Update state:** Write deploy status to `.maestro/state.local.md`
   ```
   last_deploy:
     platform: vercel
     environment: production
     url: https://my-app.vercel.app
     commit: a1b2c3d
     timestamp: 2026-03-18T12:00:00Z
     status: success
   ```

2. **Notify:** Send success notification to configured channels via notify skill
   ```
   [Deploy] my-app deployed to production
   URL: https://my-app.vercel.app
   Commit: a1b2c3d
   ```

3. **Health check** (optional, if configured):
   - Trigger awareness skill with `post_deploy` check type
   - Run smoke tests if test suite has `e2e` or `smoke` tagged tests
   - Check HTTP status of deployed URL (via curl)

## Configuration

```yaml
webhooks:
  routes:
    deploy:
      platforms: [vercel, netlify, github_actions]
      post_deploy:
        health_check: true
        smoke_tests: false
        notify: true
```

## Error Handling

- Unknown platform → log as generic deploy event, extract what fields are available
- Missing required fields → log warning, process with available data
- Post-deploy health check fails → notify with alert severity, do not roll back automatically
