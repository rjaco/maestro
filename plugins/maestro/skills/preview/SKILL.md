---
name: preview
description: "Chrome preview of UI changes using Playwright MCP. Takes screenshots across desktop, mobile, and dark mode. Presents to user for visual verification at checkpoints."
---

# Preview

Provides visual verification of UI changes by launching a browser via Playwright MCP, navigating to affected pages, and presenting screenshots to the user. Used at checkpoints during and after UI story implementation, and before milestone evaluation when the milestone contains UI work.

## When Preview Is Triggered

| Trigger | Behavior |
|---------|----------|
| Story tagged `ui: true` completes | Auto-trigger preview for all routes touched by the story |
| Milestone eval for a UI milestone | Preview all milestone routes before the evaluator agent runs |
| User runs `/preview [route]` | On-demand preview of the specified route |
| Fix story resolves a visual issue | Preview the fixed route to confirm the fix |

## Input

- URL or route path to preview (from `$ARGUMENTS` or story context)
- Dev server port (auto-detected or from project config, default: 3000)
- Optional: specific viewports to capture (defaults to all three: desktop, mobile, dark mode)
- Optional: baseline screenshot paths for comparison (before/after diff)

## Process

### Step 1: Ensure Dev Server

1. Check if a dev server is running by attempting to reach `http://localhost:3000` (or the configured port).
2. If not running, detect the start command from `package.json` (`dev`, `start`, `serve` scripts, in that order).
3. Start the dev server in the background. Poll every 2 seconds up to 30 seconds.
4. If the server fails to start within 30 seconds, report the error and abort.

```javascript
// Polling pattern used internally
await browser_navigate({ url: "http://localhost:3000" })
// If this throws, server is not ready — retry after 2s
```

### Step 2: Desktop Screenshot

Set viewport to 1440x900 and capture.

```javascript
// Playwright MCP tool calls — exact sequence
await mcp__plugin_playwright_playwright__browser_resize({
  width: 1440,
  height: 900
})

await mcp__plugin_playwright_playwright__browser_navigate({
  url: "http://localhost:3000/target-route"
})

await mcp__plugin_playwright_playwright__browser_wait_for({
  time: 2000  // allow animations and lazy loads to settle
})

await mcp__plugin_playwright_playwright__browser_take_screenshot({
  filename: "preview-desktop-{slug}.png"
})
```

### Step 3: Mobile Screenshot

Resize to 375x812 (iPhone 14 viewport) and capture.

```javascript
await mcp__plugin_playwright_playwright__browser_resize({
  width: 375,
  height: 812
})

// Page is already loaded; reload to trigger responsive breakpoints
await mcp__plugin_playwright_playwright__browser_navigate({
  url: "http://localhost:3000/target-route"
})

await mcp__plugin_playwright_playwright__browser_wait_for({
  time: 1500
})

await mcp__plugin_playwright_playwright__browser_take_screenshot({
  filename: "preview-mobile-{slug}.png"
})
```

### Step 4: Dark Mode Screenshot (if applicable)

Only run if the project has dark mode support (check for `prefers-color-scheme` media query or a dark mode class toggle in the codebase). Skip silently if dark mode is not supported.

```javascript
// Option A: CSS media query emulation
await mcp__plugin_playwright_playwright__browser_evaluate({
  code: `
    const style = document.createElement('style');
    style.textContent = '@media (prefers-color-scheme: dark) {}';
    document.head.appendChild(style);
    // Force dark mode via matchMedia override
    Object.defineProperty(window, 'matchMedia', {
      value: (query) => ({
        matches: query.includes('dark'),
        media: query,
        addEventListener: () => {},
        removeEventListener: () => {}
      })
    });
    document.documentElement.dispatchEvent(new Event('colorschemechange'));
  `
})

// Option B: Toggle a dark mode class (if the project uses class-based theming)
await mcp__plugin_playwright_playwright__browser_evaluate({
  code: `document.documentElement.classList.add('dark')`
})

await mcp__plugin_playwright_playwright__browser_take_screenshot({
  filename: "preview-dark-{slug}.png"
})
```

### Step 5: DOM Snapshot (Accessibility Quick-Check)

Capture the accessibility tree to verify semantic structure without running a full audit tool.

```javascript
await mcp__plugin_playwright_playwright__browser_snapshot()
```

Inspect the snapshot for:

| Check | What to Look For | Failure Signal |
|-------|-----------------|----------------|
| Heading hierarchy | H1 present and unique; H2s follow H1 | Multiple H1s, H3 before H2 |
| Landmark regions | `<main>`, `<nav>`, `<header>` present | No main landmark |
| Button labels | All buttons have visible text or `aria-label` | `<button>` with no text content |
| Image alt text | All `<img>` have non-empty `alt` attributes | `alt=""` on non-decorative images |
| Link text | Links have descriptive text (not "click here") | Generic link text |
| Form labels | Inputs associated with `<label>` or `aria-labelledby` | Unlabeled inputs |

Report observations inline in the user-facing output.

### Step 6: Screenshot Comparison (Before/After)

When a fix story resolves a visual issue, run a before/after comparison:

1. **Before screenshot** must exist in `.maestro/previews/before-{slug}.png` (captured before fix implementation).
2. After capturing the post-fix screenshot, present both side by side.
3. Call out specific visual differences observed between the two captures.
4. If the before screenshot does not exist, skip comparison and note it.

To capture a baseline before implementing a fix:

```javascript
await mcp__plugin_playwright_playwright__browser_take_screenshot({
  filename: "before-{slug}.png"
})
// Store in .maestro/previews/before-{slug}.png
```

### Step 7: Present to User

Format the output clearly:

```
Preview: [page name or route]
Captured: desktop 1440x900, mobile 375x812, dark mode

Desktop (1440x900):
  [screenshot]

Mobile (375x812):
  [screenshot]

Dark Mode:
  [screenshot — or "not applicable: dark mode not detected"]

DOM Structure:
  (ok)   Single H1 present
  (ok)   Main landmark found
  (warn) 2 images missing alt text: img.hero-banner, img.testimonial
  (ok)   All buttons labeled
```

### Step 8: Collect Feedback

The user can respond with:

- **"looks good"** / approve — Mark the preview as approved. Append `preview: approved` to `.maestro/state.local.md` with timestamp and route. Continue to next story or phase.
- **"looks wrong"** / reject — Ask what specifically is wrong if not obvious. Create a fix story (see Fix Story Generation below).
- **"check [other page]"** — Navigate to the requested page and repeat from Step 2.
- **Specific feedback** (e.g., "button is too small", "spacing wrong on mobile") — Create a targeted fix story immediately using the feedback as acceptance criteria.

## Fix Story Generation

When the user reports a visual issue, generate a fix story in `.maestro/stories/` using this template:

```markdown
---
id: fix-visual-{slug}-{timestamp}
title: "Fix: {user-reported issue}"
type: fix
priority: high
triggered_by: preview
---

## Context

Visual issue detected during preview of {route} on {date}.

User feedback: "{exact user words}"

## Acceptance Criteria

- [ ] {Specific visual change derived from feedback}
- [ ] Preview passes on desktop 1440x900
- [ ] Preview passes on mobile 375x812
- [ ] No new accessibility issues introduced

## Scope

Only modify visual/layout files for {route}. Do not touch logic, data fetching, or unrelated components.
```

Route the fix story back to `dev-loop` immediately after creation.

## Viewport Configurations

| Name | Width | Height | Use Case |
|------|-------|--------|----------|
| Desktop | 1440 | 900 | Standard widescreen; default |
| Laptop | 1280 | 800 | Common laptop resolution |
| Tablet landscape | 1024 | 768 | iPad landscape |
| Tablet portrait | 768 | 1024 | iPad portrait |
| Mobile (iPhone 14) | 375 | 812 | Default mobile |
| Mobile (small) | 320 | 568 | Narrow phones, stress test |

Always capture at minimum: desktop (1440x900) and mobile (375x812). Add others only when the story or user explicitly requests them.

## Fallback: When Playwright MCP Is Not Available

If `browser_navigate` or `browser_take_screenshot` are not available in the tool list:

1. Do not attempt to use the tools — they will error.
2. Inform the user:

```
Preview skipped: Playwright MCP tools are not available in this session.

To enable visual preview, ensure the Playwright MCP plugin is installed and
configured in your Claude Desktop or agent environment.

Manual verification steps:
1. Start your dev server: npm run dev
2. Open http://localhost:3000/{route} in Chrome
3. Use Chrome DevTools → Toggle device toolbar (Ctrl+Shift+M) for mobile view
4. Check dark mode via Chrome DevTools → Rendering → Emulate CSS media feature
```

3. Record in `.maestro/state.local.md` that preview was skipped and manual verification is needed.
4. Do not block story completion — mark story as complete but flag `preview: manual-required`.

## Output

- Screenshots presented inline to the user
- Accessibility observations reported per DOM snapshot
- Fix stories created in `.maestro/stories/` if visual issues reported
- Preview result recorded in `.maestro/state.local.md`:

```yaml
preview:
  route: /dashboard
  date: 2026-03-18
  status: approved  # approved | rejected | manual-required
  viewports: [desktop, mobile, dark-mode]
  issues: []
```
