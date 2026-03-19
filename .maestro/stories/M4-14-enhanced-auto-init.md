---
id: M4-14
slug: enhanced-auto-init
title: "Enhanced auto-init — detect 8 project types with smart defaults"
type: enhancement
depends_on: []
parallel_safe: true
complexity: medium
model_recommendation: sonnet
---

## Acceptance Criteria

1. Enhanced `skills/auto-init/SKILL.md` detects 8 project types:
   - Node.js (package.json)
   - Python (pyproject.toml, setup.py, requirements.txt)
   - Rust (Cargo.toml)
   - Go (go.mod)
   - Ruby (Gemfile)
   - Java (pom.xml, build.gradle)
   - PHP (composer.json)
   - Swift (Package.swift)
2. Each project type gets smart defaults in DNA:
   - Build command
   - Test command
   - Lint command
   - Common patterns
3. For monorepos (multiple project types), detects primary + secondary stacks
4. Detection runs in < 2 seconds
5. If no project type detected, falls back to generic defaults (not errors)
6. Mirror: skill in both root and plugins/maestro/

## Context for Implementer

The current auto-init skill exists at skills/auto-init/SKILL.md. Read it first. Then enhance the detection logic to cover all 8 project types.

Detection is based on marker files at the project root:
- Node.js: package.json → extract name, scripts.test, scripts.build, scripts.lint
- Python: pyproject.toml (preferred) or setup.py → extract tool.pytest section, tool.ruff
- Rust: Cargo.toml → extract package.name, cargo test, cargo clippy
- Go: go.mod → module name, go test ./..., golangci-lint
- Ruby: Gemfile → bundle exec rspec, rubocop
- Java: pom.xml (Maven) or build.gradle (Gradle) → mvn test, gradle test
- PHP: composer.json → phpunit, phpstan
- Swift: Package.swift → swift test, swiftlint

For each detected type, the DNA template should include:
```markdown
## Commands
- Build: [detected or "N/A"]
- Test: [detected or "N/A"]
- Lint: [detected or "N/A"]
```

Reference: skills/auto-init/SKILL.md (current)
Reference: skills/project-dna/SKILL.md for DNA format
Reference: templates/dna.md for DNA template
