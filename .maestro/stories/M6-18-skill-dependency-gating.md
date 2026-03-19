# S18: Declarative Skill Dependency Gating

**Milestone:** M6 — OpenClaw-Inspired Enhancements
**Priority:** Medium
**Effort:** Medium

## Tasks
- [ ] 1.1 Update `skills/skill-loader/SKILL.md` — add frontmatter gate evaluation
- [ ] 1.2 New frontmatter fields:
  ```yaml
  requires_os: darwin|linux|win32
  requires_bins: [ffmpeg, jq]
  requires_env: [MY_API_KEY]
  ```
- [ ] 1.3 At load time: check OS match, check binary availability (command -v), check env vars
- [ ] 1.4 If gates fail: skip loading skill, log reason to .maestro/logs/skill-loader.log
- [ ] 1.5 Add gate validation to /maestro doctor
- [ ] 1.6 Mirror to plugins/maestro/
