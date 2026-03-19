---
id: AA-M1
title: Service Registry & Credential Management
status: pending
stories: 4
---

# AA-M1: Service Registry & Credential Management

## Purpose
Build the foundation layer for how Maestro discovers, connects to, and authenticates with ANY external service. This is the plumbing that all other autonomous capabilities depend on.

## Stories

### S1: Service Registry Format & Config Skill
Create `.maestro/services.yaml` format and a `service-registry` skill that manages it.
- Define YAML schema for service entries (name, type, auth_method, endpoints, capabilities)
- Skill to add/remove/list/inspect services
- Template entries for common services (AWS, Cloudflare, Stripe, SendGrid, etc.)
- `/maestro connect <service>` command

### S2: Three-Tier Credential Manager
Implement three credential storage methods, user chooses per service:
- **MCP**: Service has an MCP server — config points to MCP server name
- **Vault**: age-encrypted file at `.maestro/vault.age` — unlocked at session start
- **Env**: Environment variable names mapped in services.yaml
- Credential validation on connect (test auth works)

### S3: Service Health Check & Validation
- Health check command: `/maestro services health`
- Per-service connectivity test (API ping, MCP tool list, env var presence)
- Status display: connected/disconnected/error per service
- Auto-detect available MCP servers and CLI tools

### S4: Connect/Disconnect Commands & Status Display
- `/maestro connect <service>` — interactive setup wizard
- `/maestro disconnect <service>` — remove credentials and config
- `/maestro services` — list all configured services with status
- `/maestro services status` — detailed health view

## Acceptance Criteria
1. User can add a new service via `/maestro connect aws` in under 2 minutes
2. Three credential methods all work (MCP, vault, env)
3. Health checks report accurate status for each service
4. Services.yaml is well-documented and extensible
5. Existing MCP servers auto-detected
