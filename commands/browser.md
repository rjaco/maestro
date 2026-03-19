---
name: browser
description: "Manage browser profiles, sessions, and automation"
argument-hint: "[profiles|login|screenshot|open]"
allowed-tools:
  - Read
  - Write
  - Bash
  - AskUserQuestion
  - mcp__plugin_playwright_playwright__browser_navigate
  - mcp__plugin_playwright_playwright__browser_snapshot
  - mcp__plugin_playwright_playwright__browser_take_screenshot
  - mcp__plugin_playwright_playwright__browser_close
---

# Maestro Browser

Manage browser profiles, sessions, and automation.

## Step 1: Check Arguments

Read `$ARGUMENTS` to determine the subcommand.

## Step 2: Handle Subcommand

### No arguments — Show browser status

List all saved profiles and the overall browser integration status.

```
+---------------------------------------------+
| Browser Automation                          |
+---------------------------------------------+

  Playwright MCP    [available|not detected]

  Saved Profiles:
    (ok) twitter.com     active    last login: 2026-03-19
    (ok) linkedin.com    active    last login: 2026-03-18
    (x)  instagram.com   expired   last login: 2026-03-10

  Screenshots: .maestro/browser-screenshots/ (N files)

  (i) Run /maestro browser login <site> to add or refresh a profile.
```

To generate this:
1. Check if Playwright MCP is available by attempting `browser_snapshot` availability (or note from skill detection).
2. Read all files in `.maestro/browser-profiles/` — each is a JSON profile.
3. For each profile, display: site, status, last_login date (date portion only).
4. Count files in `.maestro/browser-screenshots/` using Bash.

Use AskUserQuestion:
- Question: "What would you like to do?"
- Header: "Browser"
- Options:
  1. label: "Login to a site", description: "Authenticate and save a browser profile"
  2. label: "List profiles", description: "Show all saved browser sessions"
  3. label: "Take a screenshot", description: "Capture a screenshot of any URL"
  4. label: "Open a URL", description: "Navigate to a URL for manual inspection"

---

### `profiles` — List saved browser profiles

Read all JSON files from `.maestro/browser-profiles/`.

For each profile, display:
- Site name
- Status (`active` / `expired`)
- Last login timestamp (human-readable)
- Cookie count (number of entries in the `cookies` array)

```
+---------------------------------------------+
| Browser Profiles                            |
+---------------------------------------------+

  twitter.com
    Status:     active
    Last login: 2026-03-19 14:00 UTC
    Cookies:    12

  linkedin.com
    Status:     active
    Last login: 2026-03-18 09:30 UTC
    Cookies:    8

  (i) Profiles are stored in .maestro/browser-profiles/
  (i) Run /maestro browser login <site> to add or refresh.
```

If no profiles exist:

```
  (i) No saved profiles found.
  (i) Run /maestro browser login <site> to authenticate and save a session.
```

---

### `login <site>` — Login to a site and save profile

`<site>` is the domain name, e.g. `twitter.com`, `linkedin.com`, `github.com`.

1. Check if `.maestro/browser-profiles/<site>.json` already exists.
   - If it does, ask the user whether to refresh it or skip.

2. Use AskUserQuestion to collect credentials:
   - Question: "Enter your credentials for <site>"
   - Header: "Login"
   - Fields: username/email, password

3. Run the browser login flow:
   ```
   browser_navigate        → login page for the site (look up common URLs or ask user)
   browser_snapshot        → identify username/password fields
   browser_fill_form       → fill username
   browser_fill_form       → fill password
   browser_take_screenshot → before submitting
   browser_click           → submit/login button
   browser_wait_for        → success indicator
   browser_snapshot        → verify login (look for user avatar, dashboard, "Welcome")
   ```

4. If login succeeds:
   - Extract session via `browser_evaluate`:
     ```javascript
     JSON.stringify({ cookies: document.cookie, localStorage: { ...localStorage } })
     ```
   - Write profile to `.maestro/browser-profiles/<site>.json`:
     ```json
     {
       "site": "<site>",
       "cookies": [...],
       "localStorage": {},
       "last_login": "<ISO timestamp>",
       "status": "active"
     }
     ```
   - Take a confirmation screenshot.
   - Report success.

5. If login fails (CAPTCHA detected, wrong credentials, or unexpected page):
   - Take a screenshot.
   - Notify the user of the failure reason.
   - Do not save a profile.

**Known login URLs** (check these first before asking user):

| Site | Login URL |
|------|-----------|
| twitter.com / x.com | https://twitter.com/login |
| linkedin.com | https://www.linkedin.com/login |
| instagram.com | https://www.instagram.com/accounts/login/ |
| github.com | https://github.com/login |

For unknown sites, ask the user for the login URL.

---

### `screenshot <url>` — Take a screenshot of a URL

1. `browser_navigate` → the provided URL.
2. `browser_wait_for` → page to fully load (wait for network idle or a visible element).
3. Generate a timestamp: `date +%Y-%m-%d-%H%M%S` via Bash.
4. `browser_take_screenshot` → save to `.maestro/browser-screenshots/<timestamp>-manual.png`.
5. Report the saved path.

```
[browser] Screenshot saved:
  .maestro/browser-screenshots/2026-03-19-143022-manual.png
```

Ensure `.maestro/browser-screenshots/` exists before saving. Create it with Bash if needed.

---

### `open <url>` — Navigate to URL for manual inspection

1. `browser_navigate` → the provided URL.
2. `browser_snapshot` → get the accessibility snapshot for inspection.
3. Display a summary of the page: title, main headings, interactive elements.
4. Leave the browser open and report what was found.

```
[browser] Navigated to: https://example.com

  Title:   Example Domain
  Heading: Example Domain

  Interactive elements:
    - Link: "More information..."

  (i) Run /maestro browser screenshot <url> to capture the page.
```

This subcommand does not close the browser — it is intended for exploration and debugging.

---

## Argument Parsing

| Invocation | Behavior |
|-----------|----------|
| `/maestro browser` | Show status overview + interactive menu |
| `/maestro browser profiles` | List all saved profiles |
| `/maestro browser login <site>` | Login to `<site>` and save a profile |
| `/maestro browser screenshot <url>` | Take a screenshot of `<url>` |
| `/maestro browser open <url>` | Navigate to `<url>` and show snapshot |

`<site>` is a bare domain (e.g., `github.com`). `<url>` is a full URL including `https://`.

If `<site>` or `<url>` is missing for a subcommand that requires it:
```
[browser] Usage: /maestro browser login <site>
  Example: /maestro browser login github.com
```

## Playwright MCP Availability Check

Before attempting any Playwright operation (navigate, snapshot, screenshot), confirm Playwright MCP is available by checking whether the `mcp__plugin_playwright_playwright__browser_navigate` tool is listed as allowed in this command's frontmatter. If Playwright tools are unavailable:

```
(x) Playwright MCP is not available.

  Browser automation requires the Playwright MCP server to be running.
  To enable it:
    1. Install Playwright MCP: npm install -g @playwright/mcp
    2. Restart the Claude Code session
    3. Verify with: /maestro doctor
```

Stop here if Playwright is unavailable.

## Profile Expiry Logic

A profile's `status` field is determined at display time, not stored in the file. Compute it as follows:

| Condition | Status |
|-----------|--------|
| `last_login` within the last 7 days | `active` |
| `last_login` 7–30 days ago | `stale` |
| `last_login` more than 30 days ago | `expired` |
| `last_login` field is missing | `unknown` |

When displaying profiles, use these status labels in the output. When a profile is `expired`, add:
```
  (i) Profile expired — run /maestro browser login <site> to refresh.
```

## Profile File Format Reference

Each profile is stored at `.maestro/browser-profiles/<site>.json`:

```json
{
  "site": "github.com",
  "login_url": "https://github.com/login",
  "cookies": [
    { "name": "__Host-user_session_same_site", "value": "...", "domain": ".github.com" }
  ],
  "localStorage": {
    "user-preference-theme": "dark"
  },
  "last_login": "2026-03-19T14:00:00Z",
  "status": "active"
}
```

The `cookies` array contains the browser cookies extracted after login. The `localStorage` object contains key-value pairs from `window.localStorage`. Both fields are used to restore a session in future automation runs.

**Security note:** Profile files contain live session credentials. They are stored locally and never transmitted. Do not commit `.maestro/browser-profiles/` to git. Verify `.gitignore` includes `browser-profiles/`.

## Login Flow Details

When executing the login flow in `login <site>`:

### Step 3a: Navigate and detect fields

After `browser_navigate` to the login URL, call `browser_snapshot` and look for:
- An input with `type="email"` or `name` containing "email", "username", or "login"
- An input with `type="password"`
- A submit button with text "Sign in", "Log in", "Login", or "Continue"

If the expected fields are not found, check if already logged in (look for user avatar, "Dashboard", or username in the page title). If already logged in, skip the form fill and proceed to session extraction.

### Step 3b: Handle 2FA / CAPTCHA

After clicking submit, take a screenshot and check the snapshot for:
- A 2FA prompt (look for "verification code", "authenticator", "OTP")
- A CAPTCHA element (look for "captcha", "I'm not a robot", hCaptcha)

If 2FA is detected:
```
[browser] Two-factor authentication required for <site>.

  Please complete the 2FA step manually, then confirm when done.
```
Use AskUserQuestion to ask the user to confirm once 2FA is complete.

If CAPTCHA is detected:
```
[browser] CAPTCHA detected for <site>. Automated login cannot proceed.

  Please complete the CAPTCHA manually in the browser window,
  then run /maestro browser login <site> again.
```
Take a screenshot showing the CAPTCHA. Stop here.

## Screenshot Directory Setup

Before saving any screenshot, ensure `.maestro/browser-screenshots/` exists:

```bash
mkdir -p .maestro/browser-screenshots
```

Screenshot filenames follow the pattern `<YYYY-MM-DD-HHmmss>-<label>.png`:
- Manual screenshots: `<timestamp>-manual.png`
- Login confirmation screenshots: `<timestamp>-login-<site>.png`
- Error screenshots: `<timestamp>-error-<site>.png`

## Error Handling

| Condition | Action |
|-----------|--------|
| Playwright MCP unavailable | Show setup instructions and stop |
| `browser_navigate` fails (network error) | Show `(x) Cannot reach <url>. Check your connection.` |
| `browser_navigate` returns HTTP error page | Note the status code and proceed to snapshot; do not treat as fatal |
| Login page not found at known URL | Ask user for the login URL before proceeding |
| Login fails — wrong credentials | Take error screenshot; show failure message; do not save profile |
| Session extraction returns empty cookies | Warn `(!) No cookies extracted — session may not have been established` |
| `.maestro/browser-profiles/` cannot be created | Show `(x) Cannot create browser-profiles directory: <reason>` |
| Profile JSON file is malformed | Skip that profile in `list`/`profiles` and show `(!) Skipped malformed profile: <site>.json` |
| `browser_take_screenshot` fails | Log the failure but do not stop the overall operation |

## Examples

### Example 1: Show browser status

```
/maestro browser
```

```
+---------------------------------------------+
| Browser Automation                          |
+---------------------------------------------+

  Playwright MCP    available

  Saved Profiles:
    (ok) github.com      active    last login: 2026-03-19
    (ok) linkedin.com    active    last login: 2026-03-18
    (x)  instagram.com   expired   last login: 2026-02-01

  Screenshots: .maestro/browser-screenshots/ (7 files)

  (i) Run /maestro browser login <site> to add or refresh a profile.
```

### Example 2: Take a screenshot

```
/maestro browser screenshot https://github.com/trending
```

```
[browser] Navigating to https://github.com/trending...
[browser] Page loaded.
[browser] Screenshot saved:
  .maestro/browser-screenshots/2026-03-19-143022-manual.png
```

### Example 3: Login to GitHub

```
/maestro browser login github.com
```

```
[browser] Navigating to https://github.com/login...
[browser] Login form detected.
[browser] Filling credentials...
[browser] Submitting...
[browser] Login successful — session established.
[browser] Profile saved: .maestro/browser-profiles/github.com.json
  Cookies: 8
  Last login: 2026-03-19T14:30:00Z
```

### Example 4: Open a URL for inspection

```
/maestro browser open https://api.github.com/repos/anthropics/claude-code
```

```
[browser] Navigated to: https://api.github.com/repos/anthropics/claude-code

  Title:   (JSON response)
  Content: {"id": 12345, "name": "claude-code", "full_name": "anthropics/claude-code", ...}

  Interactive elements:
    (none — JSON response page)

  (i) Run /maestro browser screenshot <url> to capture the page.
```
