---
description: "Alias for /maestro magnum-opus. Redirects to the Magnum Opus command."
argument-hint: "VISION [--budget $N] [--hours N] [--skip-research] [--resume]"
allowed-tools: Skill
---

# /maestro opus — Redirect

This command has been renamed to `/maestro magnum-opus` to avoid confusion with the Claude Opus model name.

**Invoke the magnum-opus skill with the user's arguments:**

```
Skill("maestro:magnum-opus", args: "$ARGUMENTS")
```

Do exactly that — invoke the `maestro:magnum-opus` skill, passing through all arguments unchanged. Do not process anything yourself.
