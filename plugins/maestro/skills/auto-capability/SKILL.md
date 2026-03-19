---
name: auto-capability
description: "Detect a missing CLI tool required for a task, suggest installation options, and optionally install it with user confirmation. Always classified as T2 (reversible system change)."
---

# Auto-Capability Expansion

When a task requires a CLI tool that is not installed, this skill detects the gap, identifies the appropriate install command for the current platform, and offers to install it — always with explicit user confirmation before making any system changes.

## When to Invoke

Call this skill when:
- A `which <tool>` check returns no result (tool not in PATH)
- A CLI command fails with "command not found"
- The `smart-routing` skill falls through to API or browser because the expected CLI tool is missing

## Input

- `tool`: The CLI tool name that is missing (e.g., `aws`, `vercel`, `gh`)
- `task_description`: What the task is trying to accomplish

## Autonomy Classification

CLI installation is always **T2** (reversible system change). This means:
- Never auto-install without explicit user confirmation
- This applies even in full-auto / yolo mode
- System modifications require consent regardless of mode setting

## Process

### Step 1: Identify Available Package Managers

Check which package managers are installed:

```bash
which brew 2>/dev/null   # macOS Homebrew
which apt 2>/dev/null    # Debian/Ubuntu
which snap 2>/dev/null   # Snap (Linux)
which npm 2>/dev/null    # Node package manager
which pip 2>/dev/null    # Python package manager
which pip3 2>/dev/null   # Python 3 package manager
```

Record which ones are available.

### Step 2: Look Up Install Commands

Use the known CLI tool table:

| Tool | brew (macOS) | apt (Linux) | snap (Linux) | npm | pip |
|------|-------------|-------------|--------------|-----|-----|
| aws | `brew install awscli` | `apt install awscli` | — | — | `pip install awscli` |
| vercel | — | — | — | `npm i -g vercel` | — |
| doctl | `brew install doctl` | — | `snap install doctl` | — | — |
| wrangler | — | — | — | `npm i -g wrangler` | — |
| gh | `brew install gh` | `apt install gh` | — | — | — |
| age | `brew install age` | `apt install age` | — | — | — |
| stripe | `brew install stripe/stripe-cli/stripe` | — | — | — | — |

Select only install options whose package manager is available on the current system.

### Step 3: Display Missing Tool Notice

```
[maestro] (!) <tool> not installed.
              This task requires the <tool> CLI tool.
```

### Step 4: Prompt User

Build the option list from available package managers (max 4 options). Always include a "Skip" option.

Use AskUserQuestion:
- **Question**: "Install <tool> to continue?"
- **Header**: "Missing CLI: <tool>"
- **Options**: One entry per available package manager, plus "Skip — use API or browser instead"

Example when brew and npm are both available:
```
  1. brew install awscli        (Homebrew, macOS)
  2. pip install awscli          (pip)
  3. Skip — use API instead
```

If no package manager is available for this tool:
```
[maestro] (x) No supported package manager found for <tool>.
              Install it manually, then re-run this task.
```
Offer only "Skip" and proceed to fallback.

### Step 5: Handle Selection

**If user selects an install option:**

1. Display:
   ```
   [maestro] (i) Installing <tool> via <package-manager>...
   ```
2. Run the install command via Bash.
3. Verify installation:
   ```bash
   which <tool> && <tool> --version
   ```
4. If verification succeeds:
   ```
   [maestro] (ok) <tool> installed: <version>
   ```
   Update `.maestro/services.yaml` if the tool corresponds to a known service — set `cli_tool_installed: true` under the service entry.
   Resume task execution using the CLI route.

5. If verification fails:
   ```
   [maestro] (x) Installation completed but <tool> not found in PATH.
                 You may need to restart your shell or update PATH.
   ```
   Fall back to API or browser route via `smart-routing`.

**If user selects "Skip":**

```
[maestro] (i) Skipping <tool> install. Falling back to next available route.
```

Invoke `smart-routing` with `prefer: [api, browser]` to find the next best route. Do not attempt CLI route again.

## Output

- Missing tool notice and install prompt via AskUserQuestion
- Install + verify sequence if user approves
- `.maestro/services.yaml` updated on successful install
- Falls back to `smart-routing` on skip or install failure
- All system changes gated behind explicit user confirmation (T2 classification enforced)
