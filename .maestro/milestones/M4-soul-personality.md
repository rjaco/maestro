# M4: Enhanced SOUL & Personality

## Scope
Build a persistent autonomous personality system inspired by OpenClaw's SOUL.md. The personality persists across sessions, learns from interactions, and provides a consistent voice for all Maestro output.

## Architecture
```
.maestro/SOUL.md
    ├─ Core Identity (name, role, mission)
    ├─ Communication Style (tone, formality, humor)
    ├─ Decision Principles (quality bar, autonomy, risk tolerance)
    ├─ Learned Traits (from user feedback, corrections, confirmations)
    └─ Personality Profile (formal/casual/mentor/peer)
```

## Acceptance Criteria
1. SOUL.md is injected into every agent's context via Context Engine
2. Personality traits are learned from user corrections and confirmations
3. At least 4 personality profiles are available (formal, casual, mentor, peer)
4. SOUL updates persist across sessions
5. /maestro soul command shows and configures personality

## Stories
- S11: Enhanced SOUL.md with personality traits
- S12: Personality learning from feedback
- S13: Personality profiles (presets)
