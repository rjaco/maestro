---
name: profile
description: "Switch entire Maestro configurations — models, squad, steering, MCPs — with a single command"
argument-hint: "[list|switch NAME|create NAME|delete NAME|export]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - AskUserQuestion
---

# Maestro Profile — Config Profile Switcher

**ALWAYS display this ASCII banner as the FIRST thing in your response, before any other output:**

```
███╗   ███╗ █████╗ ███████╗███████╗████████╗██████╗  ██████╗
████╗ ████║██╔══██╗██╔════╝██╔════╝╚══██╔══╝██╔══██╗██╔═══██╗
██╔████╔██║███████║█████╗  ███████╗   ██║   ██████╔╝██║   ██║
██║╚██╔╝██║██╔══██║██╔══╝  ╚════██║   ██║   ██╔══██╗██║   ██║
██║ ╚═╝ ██║██║  ██║███████╗███████║   ██║   ██║  ██║╚██████╔╝
╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝
```

Switch the full Maestro configuration in one command. A profile bundles model assignments, squad selection, steering overrides, notification settings, and MCP server selection. Inspired by the ClaudeCTX pattern — one command to shift your entire working context.

## Step 1: Parse Subcommand

Extract the first word of `$ARGUMENTS` to determine the subcommand. The remaining words are the NAME argument.

| First word | Action |
|------------|--------|
| (empty) | Same as `list` |
| `list` | List all profiles and show active |
| `switch` | Switch to a named profile |
| `create` | Create a new profile from current config |
| `delete` | Delete a named profile |
| `export` | Export current config as shareable YAML |
| anything else | Treat as `switch NAME` (convenience shorthand) |

## Step 2: Resolve Profile Directories

Profiles live in two locations. Check both:

- `.maestro/profiles/` — team-shared, committed to git
- `.maestro/profiles/local/` — personal overrides, gitignored

Built-in profiles are referenced by name. If a local profile shadows a team profile (same filename), the local version wins.

Seven profiles ship with Maestro by default (available even if no `.maestro/profiles/` directory exists):

| Name | Model Mix | Squad | Best For |
|------|-----------|-------|----------|
| `default` | Sonnet implement, Sonnet QA, Opus architecture | quality-squad | Standard balanced work |
| `speed` | Haiku implement, Haiku QA | speed-squad | Fast iteration, boilerplate, spikes |
| `quality` | Sonnet implement, Opus QA, Opus architecture | full-squad | Production features, high-stakes PRs |
| `cost-saver` | Haiku everywhere, aggressive auto-downgrade | speed-squad | Budget-constrained runs |
| `frontend` | Sonnet implement, Sonnet QA | quality-squad | React/Next.js, design systems, Playwright |
| `backend` | Sonnet implement, Opus security-reviewer | quality-squad | APIs, databases, auth, security review |
| `content` | Haiku implement, Sonnet QA | solo | Content pipeline, SEO, marketing copy |

## Subcommand: `list` (default)

### Step L1: Read Active Profile

Read `.maestro/state.local.md`. Extract the `active_profile` field. If the file does not exist or the field is missing, treat active profile as `default`.

### Step L2: Collect Available Profiles

Merge profiles from three sources (in resolution order — last wins for display, local wins for activation):

1. Built-in defaults (always present, listed above)
2. `.maestro/profiles/*.yml` (team profiles)
3. `.maestro/profiles/local/*.yml` (personal overrides — mark with `[local]`)

For each profile file found, read the `name` and `description` fields from YAML.

### Step L3: Display

```
+---------------------------------------------+
| Config Profiles                             |
+---------------------------------------------+
  Active  [active_profile_name]

  Built-in
    default      Balanced: Sonnet/Opus, quality-squad
    speed        Fast: Haiku everywhere, speed-squad
    quality      Thorough: Sonnet+Opus, full-squad
    cost-saver   Budget: Haiku everywhere, speed-squad
    frontend     UI: Sonnet+Sonnet, quality-squad + Playwright
    backend      API: Sonnet+Opus security review, quality-squad
    content      Copy: Haiku+Sonnet, solo squad

  Custom  (.maestro/profiles/)
    [name]       [description]          [local marker if local/]
    ...
    (none)       No custom profiles yet.

  Usage:
    /maestro profile switch NAME    — Activate a profile
    /maestro profile create NAME    — Save current settings as a profile
    /maestro profile export         — Print resolved YAML for sharing
```

Mark the active profile with `*` prefix on its line.

## Subcommand: `switch NAME`

### Step S1: Validate Name

If NAME is empty:

```
[maestro] Usage: /maestro profile switch NAME

  Available profiles:
    default · speed · quality · cost-saver · frontend · backend · content
    [custom profiles, if any]
```

Stop here.

### Step S2: Resolve the Profile

1. Check `.maestro/profiles/local/NAME.yml` first (personal override wins).
2. Then check `.maestro/profiles/NAME.yml` (team profile).
3. Then check built-in defaults.

If not found in any location:

```
+---------------------------------------------+
| Profile Not Found                           |
+---------------------------------------------+
  (x) No profile named "[NAME]".

  Available profiles:
    [list profile names, one per line with brief description]

  (i) Create a new profile: /maestro profile create [NAME]
```

Stop here.

### Step S3: Resolve Inheritance

Apply deep merge in order:

1. Start with the `default` profile values.
2. If the profile declares `inherits: <other>`, merge that profile's values on top.
3. Merge the target profile's own values on top.

### Step S4: Apply the Profile

Execute these writes in order:

1. **Update active profile state** — Write `active_profile: [NAME]` into `.maestro/state.local.md`. If the file does not exist, create it with this field. If it exists, update or insert the `active_profile` line.

2. **Apply model overrides** — If the profile has a `model_overrides` block, read `.maestro/config.yaml` and update the `models` section accordingly. Preserve all other config fields.

3. **Apply squad** — If the profile has a `squad` field, update `.maestro/squad.md` — set the `name:` field only, preserving any custom `agents:` composition.

4. **Apply steering overrides** — If the profile has a `steering` block, update the relevant keys in `.maestro/steering/tech.md`. Only update specified keys — do not wipe the file.

5. **Enable MCP servers** — If the profile has an `mcp_servers` list, log the list for session awareness (Claude Code MCP state is session-managed, so output a clear notice).

6. **Log the switch** — Append to `.maestro/state.local.md`:
   ```
   [Profile] switched to [NAME] at [ISO timestamp]
   ```

### Step S5: Confirm

```
+---------------------------------------------+
| Profile Switched                            |
+---------------------------------------------+
  Active   [NAME]
  [description from profile]

  Applied:
    (ok) Models: [implement model] implement, [review model] review, [arch model] arch
    (ok) Squad:  [squad name]
    [ok or --] Steering: [keys updated, or "no overrides"]
    [ok or --] MCP servers: [list, or "none specified"]

  (i) Changes take effect immediately — no restart needed.
```

## Subcommand: `create NAME`

### Step C1: Validate Name

If NAME is empty:

```
[maestro] Usage: /maestro profile create NAME

  Tip: Choose a name that describes your current context.
  Examples: my-debug-setup, mobile-sprint, v2-rewrite
```

Stop here.

If NAME contains spaces or special characters other than `-_`, reject:

```
[maestro] Profile names must use only letters, numbers, hyphens, and underscores.
```

Stop here.

If a profile with that name already exists (in any location):

Use AskUserQuestion:
- Question: "Profile \"[NAME]\" already exists. Overwrite it?"
- Header: "Overwrite"
- Options:
  1. label: "Overwrite", description: "Replace the existing profile with the current settings"
  2. label: "Cancel", description: "Keep the existing profile unchanged"

If "Cancel", stop here.

### Step C2: Read Current Settings

Read the current state from:
- `.maestro/config.yaml` — model assignments, execution settings
- `.maestro/state.local.md` — active squad, active profile name
- `.maestro/squad.md` — current squad name
- `.maestro/steering/tech.md` — current tech steering content

### Step C3: Compose Profile YAML

Build the profile YAML from current settings:

```yaml
# .maestro/profiles/NAME.yml
name: "NAME"
description: "Created from active config on [date]"
created_at: "[ISO timestamp]"
inherits: default

model_overrides:
  implement: [current models.execution]
  review: [current models.review]
  architecture: [current models.planning]

squad: [current squad name]

steering:
  tech: "[first line of .maestro/steering/tech.md, truncated to 80 chars]"
```

### Step C4: Ask Save Location

Use AskUserQuestion:
- Question: "Where should \"[NAME]\" be saved?"
- Header: "Save Location"
- Options:
  1. label: "Team profile (.maestro/profiles/)", description: "Committed to git — shared with your team"
  2. label: "Personal profile (.maestro/profiles/local/)", description: "Gitignored — private to your machine"

### Step C5: Write Profile

Create `.maestro/profiles/NAME.yml` or `.maestro/profiles/local/NAME.yml` with the composed YAML.

If the target directory does not exist, create it.

```
+---------------------------------------------+
| Profile Created                             |
+---------------------------------------------+
  Name     [NAME]
  Location [path/to/profile.yml]
  [team or personal] profile

  (i) Activate it: /maestro profile switch [NAME]
  [if team] (i) Commit to share: git add .maestro/profiles/[NAME].yml
```

## Subcommand: `delete NAME`

### Step D1: Validate Name

If NAME is empty:

```
[maestro] Usage: /maestro profile delete NAME

  (!) Cannot delete built-in profiles (default, speed, quality, cost-saver,
      frontend, backend, content). Create a custom profile instead.
```

Stop here.

If NAME is a built-in profile:

```
[maestro] Cannot delete built-in profile "[NAME]".

  (i) Built-in profiles are always available.
  (i) To override: create a local profile with the same name.
      /maestro profile create [NAME]
```

Stop here.

### Step D2: Locate the Profile

Check `.maestro/profiles/local/NAME.yml` and `.maestro/profiles/NAME.yml`. If neither exists:

```
[maestro] No custom profile named "[NAME]" found.

  (i) Only custom profiles can be deleted.
  (i) List all profiles: /maestro profile list
```

Stop here.

If the profile is currently active (matches `active_profile` in state):

```
  (!) "[NAME]" is the currently active profile.
      Deleting it will revert to "default" after deletion.
```

### Step D3: Confirm Deletion

Use AskUserQuestion:
- Question: "Delete profile \"[NAME]\"? This cannot be undone."
- Header: "Confirm Delete"
- Options:
  1. label: "Delete", description: "Permanently remove [NAME].yml"
  2. label: "Cancel", description: "Keep the profile"

If "Cancel", stop here.

### Step D4: Delete

Remove the file. If the deleted profile was active, update `active_profile: default` in `.maestro/state.local.md`.

```
[maestro] Deleted profile "[NAME]".
[if was active] Active profile reverted to "default".
```

## Subcommand: `export`

Export the fully resolved current config as a shareable profile YAML — suitable for pasting into a team `profiles/` directory or sharing in a PR.

### Step E1: Resolve Current State

Read:
- `.maestro/config.yaml` — model assignments
- `.maestro/state.local.md` — active_profile name
- `.maestro/squad.md` — current squad
- `.maestro/steering/tech.md` — current steering

Apply the active profile's inheritance chain to get the fully resolved config.

### Step E2: Output Resolved YAML

```
+---------------------------------------------+
| Export: Resolved Config Profile             |
+---------------------------------------------+
  Based on active profile: [active_profile]
  Exported at: [ISO timestamp]

--- YAML (copy to .maestro/profiles/my-profile.yml) ---

name: "[active_profile]"
description: "Exported from [project name or cwd] on [date]"
exported_at: "[ISO timestamp]"
inherits: default

model_overrides:
  implement: [value]
  review: [value]
  architecture: [value]

squad: [value]

steering:
  tech: "[value]"

notifications:
  on_story_complete: [value]

-------------------------------------------------------

  (i) Save as: .maestro/profiles/[suggested-name].yml
  (i) Share via git: commit the file and push to your team repo.
```

## Error Handling

| Situation | Action |
|-----------|--------|
| `.maestro/` does not exist | Inform user to run `/maestro init` first |
| Profile YAML is malformed | Show parse error with line number, suggest fixing manually |
| `state.local.md` not writable | Show error and suggest checking file permissions |
| `config.yaml` not writable | Show error, skip that apply step, continue with others |
| Profile file write fails | Show error with path, suggest creating the directory manually |
| Steering file missing | Skip steering apply step, note it in output with `(--)` |
| Squad file missing | Skip squad apply step, note it in output with `(--)` |

## Output Contract

```yaml
output_contract:
  display:
    format: "box-drawing"
    sections:
      - "Config Profiles"
      - "Profile Switched"
      - "Profile Created"
      - "Export: Resolved Config Profile"
  user_decisions:
    tool: "AskUserQuestion"
    gates:
      - "Overwrite existing profile (create)"
      - "Save location — team vs personal (create)"
      - "Delete confirmation (delete)"
  data_modified:
    - ".maestro/state.local.md (active_profile, switch log)"
    - ".maestro/config.yaml (model_overrides on switch)"
    - ".maestro/squad.md (squad name on switch)"
    - ".maestro/steering/tech.md (steering keys on switch)"
    - ".maestro/profiles/NAME.yml (create, delete)"
  data_read:
    - ".maestro/state.local.md"
    - ".maestro/config.yaml"
    - ".maestro/squad.md"
    - ".maestro/steering/tech.md"
    - ".maestro/profiles/*.yml"
    - ".maestro/profiles/local/*.yml"
```
