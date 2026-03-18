---
name: product-framing
description: "Reframe feature requests into higher-value product decisions. 4 modes: Expand (think bigger), Hold (validate first), Reduce (simplify scope), Selective (pick the highest-leverage subset). Runs before decompose."
---

# Product Framing

Reframes a feature request through four product lenses before technical decomposition. Surfaces the real opportunity, surfaces premature work, simplifies overscoped requests, and identifies the highest-leverage starting point when multiple things are requested at once.

Invoke this skill before `decompose` to ensure the team is solving the right problem, not just the stated one.

## Input

- Feature description (from `$ARGUMENTS` or passed by `maestro.md` after Step 5 — Classify)
- Optional: `--framing` flag in the original `/maestro` invocation
- Optional: classifier signal indicating a vague or broad request

## When to Run

Product Framing is **optional but recommended** in these situations:

| Signal | Trigger |
|--------|---------|
| User passes `--framing` flag | Always run |
| Classifier detects scope as `multi-story` or `magnum opus candidate` | Suggest running |
| Request contains words like "full", "complete", "entire", "whole", "build a [noun]" | Suggest running |
| Request lists 3 or more distinct features in one sentence | Always run |
| Request sounds like a solution rather than a problem ("add X" without context of why) | Suggest running |

When the trigger is "suggest running", use AskUserQuestion to offer framing before proceeding:
- Question: "This request looks broad. Would you like product framing before decomposing?"
- Header: "Product Framing"
- Options: "Yes, frame it first (Recommended)", "No, go straight to decompose"

## The 4 Framing Modes

### Expand — Think Bigger

The request is too narrow. The user is solving a symptom rather than the underlying opportunity. Surface the broader problem and the fuller solution space.

**When to apply:** The request is a small, specific feature but the user's actual need is larger. Completing only the stated request would require immediate follow-up work or leaves obvious adjacent value on the table.

**Examples:**

| Stated Request | Expanded Opportunity |
|---------------|----------------------|
| "Add password reset" | "Build a complete auth recovery flow: password reset, email verification, account lockout handling, and security notifications" |
| "Add a loading spinner" | "Implement a consistent loading state system across all async actions — spinner, skeleton screens, and error states" |
| "Export to CSV" | "Build a data export system: CSV, JSON, and PDF with column selection and scheduled exports" |
| "Add a search bar" | "Build full-text search with filters, keyboard navigation, and recent/saved searches" |

**Output:** Broader scope with higher user value. The expanded description replaces the original in decompose.

---

### Hold — Validate First

The request may be premature. Building it now without data or user validation risks wasting significant effort. Suggest a cheaper validation step first.

**When to apply:** The feature involves significant complexity, assumptions about user behavior, or requires data that does not yet exist. Shipping the feature without validation could mean building the wrong thing.

**Examples:**

| Stated Request | Hold Recommendation |
|---------------|---------------------|
| "Build a recommendation engine" | "Do we have enough user behavior data? Consider adding event tracking first, then validate recommendations with a simple rule-based approach before training a model" |
| "Add social sharing features" | "Are users actually trying to share? Check if referral traffic exists in analytics before building a sharing system" |
| "Build a dark mode" | "Dark mode has significant implementation cost. Is this user-requested? Check feedback channels for demand before prioritizing" |
| "Add real-time collaboration" | "Real-time infra is expensive to build and maintain. Validate with a simpler async version (last-writer-wins) first" |

**Output:** A validation task or prerequisite step that should happen before building the original request. Framing surfaces the prerequisite; the user decides whether to build that first, or proceed anyway with the original.

---

### Reduce — Simplify Scope

The request is too ambitious for the current stage. Ship a smaller, still-valuable version first, learn from it, and iterate.

**When to apply:** The request describes a system or platform when a feature would suffice. The scope implies weeks of work when days would deliver 80% of the value.

**Examples:**

| Stated Request | Reduced Scope |
|---------------|---------------|
| "Build a full CRM" | "Start with contact management and a basic pipeline view. Ship, learn what fields users actually use, then extend" |
| "Build a complete notification system" | "Start with email-only notifications for the highest-priority event type. Add channels and event types after validating the pattern" |
| "Add a full admin dashboard" | "Start with read-only metrics for the 3 most-asked questions. Build write operations after seeing what admins actually need" |
| "Build a plugin system" | "Hardcode the 2-3 integrations users need most. Extract a plugin API only after the integration patterns stabilize" |

**Output:** A scoped-down version of the original request. The reduced description replaces the original in decompose.

---

### Selective — Pick the Highest-Leverage Subset

Multiple things are requested. Not all of them are equal in value or urgency. Rank them and recommend shipping the most impactful one first.

**When to apply:** The request lists multiple distinct features, improvements, or concerns. Building all of them in parallel creates dependencies, delays shipping, and obscures what actually mattered.

**Examples:**

| Stated Request | Selective Recommendation |
|---------------|--------------------------|
| "Add auth, notifications, and dark mode" | "Auth unblocks all user-specific features — ship it first. Notifications drive engagement — ship second. Dark mode is cosmetic and has no blocking dependencies — ship last" |
| "Fix performance, add pagination, and improve search" | "Pagination reduces server load and unblocks the performance work. Fix pagination first, then measure performance, then improve search" |
| "Add OAuth, email templates, and password strength rules" | "OAuth eliminates password storage concerns entirely. If OAuth is the end state, password strength rules are low ROI. Start with OAuth, then email templates" |
| "Improve onboarding, add a tutorial, and add tooltips" | "Onboarding converts new users; tutorials and tooltips optimize existing users. If retention is low, fix onboarding first" |

**Output:** An ordered list of the requested items ranked by leverage, with the top-ranked item as the recommended starting point. Decompose proceeds with the top-ranked item only, unless the user selects a different one.

---

## Process

### Step 1: Read the Feature Description

Read the feature request from `$ARGUMENTS` or from the feature description passed by `maestro.md`.

Identify:
- The stated request (what the user asked for)
- The implied need (what problem they are trying to solve)
- Any scope signals (words like "full", "complete", "system", "platform", multiple features listed)

### Step 2: Analyze Using All 4 Lenses

Apply each framing mode independently to the request. For each mode, determine:

- Is this mode relevant to this request?
- If yes, what specific reframing does it suggest?
- What is the rationale?

Do not force every mode to apply. Some requests are cleanly served by one or two modes. Mark irrelevant modes as "N/A" with a brief reason.

### Step 3: Determine Recommendation

Select the single most relevant mode as the recommendation:

| Situation | Recommended Mode |
|-----------|-----------------|
| Request is clearly too narrow — obvious adjacent value | Expand |
| Request lacks validation data or assumes user behavior | Hold |
| Request scope implies more than 2 weeks of work | Reduce |
| Request lists 3+ distinct features | Selective |
| Request is well-scoped, clear, and appropriately sized | None — proceed directly |

If "None", skip the AskUserQuestion step and pass the original description directly to decompose.

### Step 4: Present Framing Analysis

Display the framing output using this format:

```
+---------------------------------------------+
| Product Framing                             |
+---------------------------------------------+
  Feature: [original description]

  Expand  [one-sentence bigger opportunity, or "N/A — request is appropriately scoped"]
  Hold    [one-sentence validation suggestion, or "N/A — sufficient data exists to build"]
  Reduce  [one-sentence minimal viable scope, or "N/A — request is already well-scoped"]
  Select  [ordered list of items by leverage, or "N/A — single concern"]

  Recommendation: [mode] — [one-sentence rationale]
```

### Step 5: Ask User Which Mode to Use

Use AskUserQuestion:
- Question: "Proceed with [recommended mode]?"
- Header: "Product Framing"
- Options:
  1. label: "Use [recommended mode] (Recommended)", description: "[brief description of what this produces]"
  2. label: "Choose different mode", description: "Select Expand, Hold, Reduce, or Selective manually"
  3. label: "Skip framing", description: "Pass the original description to decompose unchanged"

If the user selects "Choose different mode", present the four modes as options and ask which to apply.

If the user selects "Skip framing", pass the original description unchanged to decompose.

### Step 6: Produce Refined Description

Based on the selected mode, produce a refined feature description:

- **Expand**: Write the broader opportunity as a clear feature description
- **Hold**: Write the validation task as the feature description, and append a note: `[Note: original request — [original] — held pending validation]`
- **Reduce**: Write the scoped-down version as the feature description, and append a note: `[Deferred: [deferred scope] — revisit after shipping this]`
- **Selective**: Write the top-ranked item as the feature description, and append a note: `[Deferred: [remaining items] — ranked for subsequent iterations]`

## Output

The refined feature description is returned to the caller (`maestro.md`). It replaces the original `DESCRIPTION` in Step 9 (Decompose).

If a Hold or Reduce framing was applied, log the deferred scope to `.maestro/deferred.md`:

```markdown
# Deferred Scope

Items surfaced by Product Framing but explicitly deferred for later iterations.

## [Date] — [Original Feature Name]

- **Mode applied:** [Hold / Reduce / Selective]
- **Original request:** [verbatim]
- **What was deferred:** [description of deferred scope]
- **Why deferred:** [rationale from framing analysis]
- **Revisit when:** [condition or milestone that would trigger revisiting this]
```

## Integration with maestro.md

Product Framing is invoked between **Step 5 (Classify)** and **Step 9 (Decompose)**.

In `maestro.md`, this hook point is:

```
Step 5  → Classify the request
           |
           +--> [if --framing flag OR vague/broad signal detected]
           |    Invoke product-framing skill
           |    Replace DESCRIPTION with refined description
           |
           v
Step 6  → Forecast
...
Step 9  → Decompose (receives refined description)
```

The `--framing` flag is added to the existing flag table in `maestro.md`:

| Flag | Variable | Default |
|------|----------|---------|
| `--framing` | FRAMING=true | false |

When `FRAMING=true`, always run the product-framing skill regardless of classifier scope signals.

## Integration with decompose

The `decompose` skill receives the refined description as its feature input. No changes to the decompose skill are required — it consumes the refined description the same way it consumes the original.

If the Hold mode was selected, decompose receives the validation task description (not the original feature). The original feature description is preserved in `.maestro/deferred.md` for future sessions.

## Example: Full Run

**Original request:** "Add auth, notifications, and dark mode to the app"

**Framing analysis:**

```
+---------------------------------------------+
| Product Framing                             |
+---------------------------------------------+
  Feature: Add auth, notifications, and dark mode to the app

  Expand  Auth could include full account management: OAuth, SSO,
          team invites, and role-based access — not just login/logout
  Hold    N/A — these are known user needs, no validation required
  Reduce  N/A — each item is already a reasonable feature unit
  Select  1. Auth — unblocks all user-specific features and personalization
          2. Notifications — drives re-engagement, depends on auth
          3. Dark mode — cosmetic, no dependencies, lowest leverage now

  Recommendation: Selective — three distinct features; auth has the
  highest leverage and unblocks the others
```

**User selects:** "Use Selective (Recommended)"

**Refined description passed to decompose:**
> "Add user authentication (login, logout, session management)"
> [Deferred: notifications, dark mode — ranked for subsequent iterations]

**Deferred scope logged to `.maestro/deferred.md`:**
- Notifications (revisit after auth ships)
- Dark mode (revisit after core features are stable)
