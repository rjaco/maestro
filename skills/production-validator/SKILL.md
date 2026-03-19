---
name: production-validator
description: "Pre-ship validation gate that detects mock implementations, placeholder code, debug artifacts, and non-production patterns."
---

# Production Validator

A pre-ship gate that blocks shipping if the codebase contains mock implementations, placeholder code, debug artifacts, hardcoded credentials, or unimplemented stubs. Runs automatically as part of `/maestro ship` before PR creation.

## How It Works

The validator runs `scripts/production-validate.sh` against the codebase. Each check either passes or fails. A single failure blocks the ship unless overridden with a documented exception.

## Checks

| Check | What It Catches |
|-------|----------------|
| Mock/Stub detection | `mock`, `fake`, `stub`, `dummy` in variable/function names outside test files |
| TODO/FIXME detection | Unresolved `TODO`, `FIXME`, `HACK`, `XXX` comments outside docs |
| Debug artifact detection | `console.log`, `print(`, `debugger`, `binding.pry`, `import pdb` |
| Hardcoded credentials | `password =`, `api_key =`, `secret =`, `token =` with literal string values |
| Placeholder detection | `example.com`, `lorem ipsum`, `placeholder`, `test@test.com` |
| Unimplemented code | `throw new Error("not implemented")`, `raise NotImplementedError`, `todo!()` |

## Script

The validator is implemented in `scripts/production-validate.sh`. Run it directly:

```bash
# Default: scan current directory, exit 0 on pass, 1 on fail
./scripts/production-validate.sh

# Scan a specific path
./scripts/production-validate.sh src/

# Strict mode: warnings also cause failure
./scripts/production-validate.sh --strict

# Combine flags
./scripts/production-validate.sh --strict src/api/
```

## Output Format

```
Production Validator Results
============================
[PASS] Mock/Stub detection
[FAIL] TODO/FIXME detection
  - src/api.ts:42: TODO: implement rate limiting
  - src/auth.ts:15: FIXME: validate token expiry
[PASS] Debug artifact detection
[FAIL] Hardcoded credentials
  - config/dev.ts:8: api_key = "sk-test-..."
[PASS] Placeholder detection
[PASS] Unimplemented code

Result: 2 checks FAILED. Fix before shipping.
```

Exit code 0 when all checks pass. Exit code 1 when any check fails.

## Ship Integration

The validator runs automatically inside `/maestro ship`:

1. All stories pass QA review
2. **Production validator runs** — blocks if any check fails
3. Git craft creates the commit
4. PR is created

If the validator fails, the ship is halted. The orchestrator surfaces the failures to the user with the exact file:line locations. The user must either fix the issues or explicitly override with a documented reason.

## Override Mechanism

Some findings are intentional (a `TODO` in a changelog, a `placeholder` in test fixtures). To suppress a specific finding, add an inline annotation:

```typescript
// production-validate: ignore
const debugMode = true; // intentional for demo environment
```

Or use a `.production-validate-ignore` file at the project root (gitignored patterns, same syntax as `.gitignore`):

```
# Ignore test fixtures that contain placeholder data
tests/fixtures/**
docs/**
CHANGELOG.md
```

## Logging

Results are appended to `.maestro/logs/production-validate.log`:

```
[2026-03-18T14:22:01] PASS all-checks | path: . | strict: false
[2026-03-18T14:35:44] FAIL 2-checks | path: . | strict: false
  TODO/FIXME: src/api.ts:42, src/auth.ts:15
  Hardcoded credentials: config/dev.ts:8
```

## Integration Points

- **Invoked by:** `/maestro ship` (automatic), SPARC Phase 5 (automatic), developer directly (manual)
- **Script:** `scripts/production-validate.sh`
- **Reads from:** project source files (respects `.production-validate-ignore`)
- **Writes to:** `.maestro/logs/production-validate.log`
- **Blocks:** PR creation, commit finalization in SPARC Completion phase
