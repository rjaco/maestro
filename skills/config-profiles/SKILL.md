---
name: config-profiles
description: "Switch entire Maestro configurations — models, squad, steering, MCP servers, notifications — with a single command. Profiles live in .maestro/profiles/ and are committed to git for team sharing."
---

# Config Profiles

Switches the full Maestro configuration in one command. A profile bundles model assignments, squad selection, active steering overrides, notification settings, and MCP server selection. Inspired by the ClaudeCTX pattern — one command to shift your entire working context.

## What a Profile Contains

| Field | Description |
|-------|-------------|
| `model_overrides` | Per-agent model assignments (haiku / sonnet / opus) |
| `squad` | Which squad template to activate (e.g. `quality-squad`) |
| `steering` | Key-value overrides written into `.maestro/steering/tech.md` |
| `notifications` | Notification provider settings and triggers |
| `mcp_servers` | List of MCP servers to enable for this profile |
| `config_overrides` | Arbitrary `.maestro/config.yml` key overrides |

## Storage Format

Profiles live in `.maestro/profiles/` as YAML files. The filename (minus `.yml`) is the profile name used in commands.

```yaml
# .maestro/profiles/frontend-heavy.yml
name: "Frontend Heavy"
description: "Optimized for React/Next.js frontend work"
inherits: default

model_overrides:
  implement: sonnet
  review: sonnet
  architecture: opus

squad: quality-squad

steering:
  tech: "React 19 + Next.js 15 + Tailwind"

notifications:
  on_story_complete: true

mcp_servers:
  - playwright
  - figma
```

## Built-In Profiles

Seven profiles ship with Maestro. Copy and customize any into `.maestro/profiles/` to override.

| Profile | Model Mix | Squad | Best For |
|---------|-----------|-------|----------|
| `default` | Sonnet implement, Sonnet QA, Opus architecture | quality-squad | Standard balanced work |
| `speed` | Haiku implement, Haiku QA | speed-squad | Fast iteration, boilerplate, spikes |
| `quality` | Sonnet implement, Opus QA, Opus architecture | full-squad | Production features, high-stakes PRs |
| `cost-saver` | Haiku everywhere, aggressive auto-downgrade | speed-squad | Budget-constrained runs |
| `frontend` | Sonnet implement, Sonnet QA | quality-squad | React/Next.js, design systems, Playwright |
| `backend` | Sonnet implement, Opus security-reviewer | quality-squad | APIs, databases, auth, security review |
| `content` | Haiku implement, Sonnet QA | solo | Content pipeline, SEO, marketing copy |

## Switching Mechanism

Four subcommands cover the full lifecycle:

| Command | Effect |
|---------|--------|
| `/maestro config profile <name>` | Activate a profile immediately |
| `/maestro config profile list` | List all available profiles with active marker |
| `/maestro config profile create <name>` | Create a new profile from current active settings |
| `/maestro config profile export <name>` | Print the resolved profile YAML to stdout for sharing |

Profile changes are **instant** — no restart needed. The active profile name is written to `.maestro/state.local.md` and read by delegation, squad, and status on the next dispatch.

### Activation Behavior

When `/maestro config profile <name>` runs:

1. Resolve the profile (apply inheritance, merge with defaults).
2. Write `active_profile: <name>` to `.maestro/state.local.md`.
3. Write resolved `model_overrides` into the delegation model-selection state.
4. Write the squad name into `.maestro/squad.md` (only the `name` field — preserves any custom composition).
5. If `steering` overrides are present, update the relevant keys in `.maestro/steering/tech.md`.
6. Enable the listed `mcp_servers` in the session.
7. Log the switch: `[Profile] switched to <name> at <timestamp>`.

## Profile Inheritance

Every profile inherits from `default`. Only fields that differ need to be specified — unset fields keep the default value.

Merge strategy: **deep merge**. Profile values override default values at the leaf level. A `model_overrides` block in a profile does not wipe the default `model_overrides` — it overlays key by key.

```yaml
# default model_overrides:
#   implement: sonnet
#   review: sonnet
#   architecture: opus

# speed model_overrides (partial):
#   implement: haiku
#   review: haiku

# Resolved speed profile:
#   implement: haiku    ← from speed
#   review: haiku       ← from speed
#   architecture: opus  ← inherited from default
```

Profiles may declare `inherits: <other-profile>` to chain from a non-default base. Chains resolve in order: `default` → `base` → `profile`.

## Team Sharing

Profiles in `.maestro/profiles/` are committed to git. Team members clone the repo and immediately have access to the same profiles.

**Personal overrides** go in `.maestro/profiles/local/` — this directory is gitignored. A local profile with the same name as a team profile shadows it for that user only.

```
.maestro/
  profiles/
    default.yml        ← committed, team-shared
    frontend-heavy.yml ← committed, team-shared
    local/
      frontend-heavy.yml  ← gitignored, personal override
```

The resolver checks `local/` first. If a matching profile exists there, it wins.

## Integration Points

| Skill / Command | How It Uses Profiles |
|----------------|----------------------|
| `init/` command | After stack detection, suggests the best-fit profile by name |
| `delegation/SKILL.md` | Reads `model_overrides` from active profile before model selection |
| `squad/SKILL.md` | Reads `squad` field from active profile to load the correct squad template |
| `status/` command | Displays `Active profile: <name>` in the session header |
| `notify/SKILL.md` | Reads `notifications` block from active profile for trigger configuration |
| `mcp-detect/SKILL.md` | Profile `mcp_servers` list seeds the enabled-server set at session start |
