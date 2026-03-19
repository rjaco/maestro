---
name: browser-agent
description: "Automate web interactions using Playwright MCP. Handles login/session management, form filling, social media posting, and purchase flows with screenshot audit trails and T3 approval gates."
---

# Browser Automation Skill

Automates web interactions for sites that do not have an API. Uses Playwright MCP tools (prefix: `mcp__plugin_playwright_playwright__`) to navigate, interact, and capture evidence.

## Tool Reference

| Tool | Purpose |
|------|---------|
| `mcp__plugin_playwright_playwright__browser_navigate` | Navigate to a URL |
| `mcp__plugin_playwright_playwright__browser_snapshot` | Get page accessibility snapshot |
| `mcp__plugin_playwright_playwright__browser_click` | Click an element |
| `mcp__plugin_playwright_playwright__browser_fill_form` | Fill form fields |
| `mcp__plugin_playwright_playwright__browser_type` | Type text into focused element |
| `mcp__plugin_playwright_playwright__browser_press_key` | Press keyboard keys |
| `mcp__plugin_playwright_playwright__browser_select_option` | Select dropdown options |
| `mcp__plugin_playwright_playwright__browser_hover` | Hover over elements |
| `mcp__plugin_playwright_playwright__browser_drag` | Drag and drop |
| `mcp__plugin_playwright_playwright__browser_take_screenshot` | Capture screenshot |
| `mcp__plugin_playwright_playwright__browser_evaluate` | Execute JavaScript in page |
| `mcp__plugin_playwright_playwright__browser_file_upload` | Upload files |
| `mcp__plugin_playwright_playwright__browser_handle_dialog` | Handle alerts/confirms/prompts |
| `mcp__plugin_playwright_playwright__browser_wait_for` | Wait for elements or conditions |
| `mcp__plugin_playwright_playwright__browser_navigate_back` | Go back in browser history |
| `mcp__plugin_playwright_playwright__browser_tabs` | Manage browser tabs |
| `mcp__plugin_playwright_playwright__browser_console_messages` | Read console output |
| `mcp__plugin_playwright_playwright__browser_network_requests` | Monitor network requests |
| `mcp__plugin_playwright_playwright__browser_close` | Close browser |
| `mcp__plugin_playwright_playwright__browser_resize` | Resize viewport |
| `mcp__plugin_playwright_playwright__browser_run_code` | Run code in browser context |
| `mcp__plugin_playwright_playwright__browser_install` | Install browser |

## Session Management

Browser profiles persist login state across sessions. Store profiles at `.maestro/browser-profiles/<site>.json`.

### Profile Format

```json
{
  "site": "twitter.com",
  "cookies": [...],
  "localStorage": {},
  "last_login": "2026-03-19T14:00:00Z",
  "status": "active"
}
```

### Loading a Profile

Before navigating to a site:
1. Check if `.maestro/browser-profiles/<site>.json` exists.
2. If it exists and `status` is `active`, inject cookies via `browser_evaluate`:
   ```javascript
   // Set each cookie using document.cookie or the browser context
   ```
3. Navigate to the site and run `browser_snapshot` to verify the session is still valid (look for logged-in indicators: username, avatar, dashboard elements).
4. If the session is invalid, proceed with the login flow below.

### Login Flow

```
1. browser_navigate        → login page URL
2. browser_snapshot        → identify username/password fields and submit button
3. browser_fill_form       → username field with credential from credential manager
4. browser_fill_form       → password field with credential from credential manager
5. browser_click           → submit/login button
6. browser_wait_for        → navigation or success element
7. browser_snapshot        → verify login (look for user avatar, dashboard, "Welcome")
8. browser_evaluate        → extract document.cookie and localStorage snapshot
9. Write profile JSON      → .maestro/browser-profiles/<site>.json
```

Credentials must come from the project credential manager — never hardcode or echo them. If credentials are not stored, ask the user with AskUserQuestion before proceeding.

### Saving a Profile

After successful login, extract session state via `browser_evaluate` and write to the profile file:

```javascript
// Extract cookies (may require server-side injection via CDP — use what Playwright exposes)
JSON.stringify({ cookies: document.cookie, localStorage: { ...localStorage } })
```

Update `last_login` to the current ISO timestamp and set `status: "active"`.

## Screenshot Audit Trail

Take a screenshot before every significant action. This creates an evidence trail for irreversible operations.

**When to screenshot:**
- Before clicking Submit, Post, Buy, Confirm, Delete
- Before and after form fill on multi-step flows
- After login to confirm session
- After any T3 action completes to capture the confirmation

**Naming convention:** `.maestro/browser-screenshots/YYYY-MM-DD-HHMMSS-<action>.png`

Example: `.maestro/browser-screenshots/2026-03-19-143022-tweet-post.png`

**Reference in notifications:** When sending an action receipt to the notification hub, include the screenshot path so the user can verify what happened.

```
[browser-agent] Action completed: tweet posted
Screenshot: .maestro/browser-screenshots/2026-03-19-143022-tweet-post.png
```

Ensure `.maestro/browser-screenshots/` exists before writing. Create it with Bash if needed.

## Form Filling Strategy

1. Run `browser_snapshot` to understand the full page structure — read field labels, input types, and button text.
2. Map each required data item to its field by label or placeholder.
3. Fill fields one at a time using `browser_fill_form`.
4. For `<select>` dropdowns, use `browser_select_option`.
5. For checkboxes and radio buttons, use `browser_click`.
6. After all fields are filled, run `browser_snapshot` again to verify values before submit.
7. For multi-step forms: click Next/Continue, wait for the next step to load, then repeat.

### Multi-Step Forms

```
Step N:
  browser_snapshot        → read current step fields
  browser_fill_form       → fill each field
  browser_snapshot        → verify filled values
  browser_click           → "Next" or "Continue" button
  browser_wait_for        → next step indicator

Repeat until final step, then apply purchase flow safety if applicable.
```

## Purchase Flow Safety

Purchase actions are always T3 (irreversible). Never complete a purchase without explicit user approval.

```
1. browser_navigate        → product or cart page
2. browser_snapshot        → confirm cart contents and total
3. browser_take_screenshot → capture order summary (REQUIRED)
4. Request T3 approval     → show user: item, price, total, screenshot path
5. WAIT for approval       → do not proceed without explicit "yes"
6. browser_click           → final "Place Order" / "Complete Purchase" button
7. browser_wait_for        → order confirmation page
8. browser_take_screenshot → capture order confirmation number
9. Send notification       → include confirmation number and screenshot
```

The approval message to the user must include:
- What is being purchased
- The price and total
- The merchant/site
- The screenshot path showing the order summary

Never click the final purchase button without approval. If the user is unavailable, pause and notify.

## CAPTCHA Handling

Never attempt to auto-solve CAPTCHAs. They require human interaction.

### Detection

After navigating or submitting a form, run `browser_snapshot` and scan for CAPTCHA indicators:
- Text containing: "captcha", "I'm not a robot", "verify you are human", "reCAPTCHA", "hCaptcha", "Cloudflare"
- Elements with class names: `g-recaptcha`, `h-captcha`, `cf-turnstile`

### Response

When CAPTCHA is detected:

```
1. browser_take_screenshot → capture CAPTCHA page
2. Pause all automation
3. Notify user:
   "[browser-agent] CAPTCHA detected on <site>.
    Please solve it manually in the browser.
    Screenshot: .maestro/browser-screenshots/<timestamp>-captcha.png
    Reply when complete to resume."
4. Wait for user confirmation before continuing
```

## Common Workflows

### Login to a Website

```
1. browser_navigate        → login page URL
2. browser_snapshot        → find username/password fields
3. browser_fill_form       → username
4. browser_fill_form       → password
5. browser_click           → submit button
6. browser_wait_for        → navigation or success indicator
7. browser_snapshot        → verify login success
8. Save session            → .maestro/browser-profiles/<site>.json
```

### Post on Social Media

See `social-media.md` for platform-specific details.

General flow:
```
1. Load or establish session for the platform
2. browser_navigate        → compose URL or find compose button
3. browser_snapshot        → locate post input area
4. browser_type            → post content
5. browser_take_screenshot → audit trail before posting
6. Request T3 approval     → content is public and irreversible
7. WAIT for approval
8. browser_click           → "Post" / "Share" / "Publish" button
9. browser_snapshot        → confirm posted (look for success indicator)
```

### Fill a Registration Form

```
1. browser_navigate        → registration page
2. browser_snapshot        → understand all form fields
3. For each field:
   - browser_fill_form     → text inputs
   - browser_select_option → dropdowns
   - browser_click         → checkboxes, radio buttons
4. browser_take_screenshot → before submit
5. If T3: request approval → confirm before submitting
6. browser_click           → submit button
7. browser_snapshot        → confirm registration success
```

### Monitor a Page for Changes

```
1. browser_navigate        → target URL
2. browser_snapshot        → capture current state as baseline
3. browser_evaluate        → extract relevant data (price, status, text)
4. Store baseline          → write to .maestro/browser-snapshots/<site>-baseline.json
5. On next check: compare current state to baseline
6. If changed: notify user with diff summary
```

## Tier Classification

Browser actions are classified the same as all other Maestro actions:

| Action | Tier | Rationale |
|--------|------|-----------|
| Navigate, snapshot, screenshot | T1 | Read-only, reversible |
| Fill form (not submitted) | T1 | No side effects yet |
| Login, save profile | T2 | Persistent but recoverable |
| Form submit (non-purchase) | T2 | Usually reversible |
| Social media post | T3 | Public, irreversible |
| Purchase / payment | T3 | Financial, irreversible |
| Account deletion | T3 | Destructive, irreversible |
| Sending email/message | T3 | External communication |

Always use the autonomy engine's tier classification rules. When in doubt, escalate to T3.

## Error Handling

### Page Load Failure
- Run `browser_snapshot` after navigate to confirm page loaded.
- If snapshot shows error page (404, 500, "connection refused"), notify user and abort.

### Element Not Found
- Run `browser_snapshot` to re-read the page — the UI may have changed.
- Try alternative selectors (label text, placeholder, aria-label).
- If still not found after two attempts, screenshot and notify user.

### Session Expired
- Detected when snapshot shows a login form on a page that should be authenticated.
- Delete or mark profile as `status: "expired"`.
- Re-run the login flow and retry the original action.

### Network Errors
- Use `browser_network_requests` to check if requests are failing.
- Check `browser_console_messages` for JavaScript errors.
- Report to user with details.
