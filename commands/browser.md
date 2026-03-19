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
