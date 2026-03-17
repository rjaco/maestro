---
name: preview
description: "Chrome preview of UI changes using Playwright. Takes screenshots and presents to user for visual verification at checkpoints."
---

# Preview

Provides visual verification of UI changes by launching a browser via Playwright MCP, navigating to affected pages, and presenting screenshots to the user. Used at checkpoints during and after story implementation.

## Input

- URL or route path to preview (from `$ARGUMENTS` or story context)
- Dev server port (auto-detected or from project config)
- Optional: viewport size (defaults to desktop 1440x900 and mobile 375x812)

## Process

### Step 1: Ensure Dev Server

1. Check if a dev server is already running by attempting to reach `http://localhost:3000` (or the configured port).
2. If not running, start the dev server in the background:
   - Detect the start command from package.json (`dev`, `start`, `serve`)
   - Run it in the background
   - Wait for the server to be reachable (poll with short intervals, max 30 seconds)
3. If the server fails to start, report the error and abort.

### Step 2: Navigate and Capture

For each URL or route to preview:

1. **Desktop viewport** — Set browser to 1440x900 using `browser_resize`. Navigate to the page using `browser_navigate`. Wait for the page to settle (network idle or 2-second timeout). Take a screenshot with `browser_take_screenshot`.

2. **Mobile viewport** — Set browser to 375x812 using `browser_resize`. Reload the page. Take a screenshot with `browser_take_screenshot`.

3. **Dark mode** (if applicable) — If the project supports dark mode, toggle it via `browser_evaluate` (set `prefers-color-scheme: dark` or toggle a class). Take another screenshot.

### Step 3: DOM Snapshot

Take a `browser_snapshot` to capture the accessibility tree. Use this to verify:
- Semantic HTML structure (headings, landmarks, links)
- Interactive elements are properly labeled
- No broken or empty elements

### Step 4: Present to User

Show the screenshots to the user with context:

```
Preview: [page name or route]

Desktop (1440x900): [screenshot]
Mobile (375x812): [screenshot]
Dark mode: [screenshot if applicable]

DOM structure looks [clean / has issues]:
- [any structural observations]
```

### Step 5: Collect Feedback

The user can respond with:

- **"looks good"** / **approve** — Mark the preview as approved. Continue to next story or phase.
- **"looks wrong"** / **reject** — Ask the user what specifically is wrong. Create a fix story with the user's feedback as acceptance criteria. Route the fix story back to `dev-loop`.
- **"check [other page]"** — Navigate to the requested page and repeat from Step 2.
- **specific feedback** — (e.g., "the button is too small", "spacing is off on mobile") — Create a targeted fix story with the feedback.

## Prerequisites

- Playwright MCP tools must be available (`browser_navigate`, `browser_take_screenshot`, `browser_snapshot`, `browser_resize`)
- A dev server must be runnable for the project
- If Playwright is not available, inform the user and suggest manual verification

## Output

- Screenshots presented inline to the user
- Fix stories created if the user reports visual issues
- Preview approval recorded in `.maestro/state.local.md`
