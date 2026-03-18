---
name: test-gen
description: "Auto-generate tests for story changes. Unit tests for functions, integration tests for APIs, component tests for UI."
---

# Test Generation

Automatically generate tests for code changes made during a story.

## Detection

Analyze files created/modified by the implementer:

| File Type | Test Type | Pattern |
|-----------|-----------|---------|
| `src/lib/*.ts` | Unit test | `src/lib/*.test.ts` |
| `src/app/api/**/*.ts` | Integration test | `src/app/api/**/*.test.ts` |
| `src/components/*.tsx` | Component test | `src/components/*.test.tsx` |
| `src/middleware.ts` | Middleware test | `src/middleware.test.ts` |
| `src/utils/*.ts` | Unit test | `src/utils/*.test.ts` |

## Test Framework Detection

Read from DNA:

| Framework | Import | Runner |
|-----------|--------|--------|
| Vitest | `import { describe, it, expect } from 'vitest'` | `vitest run` |
| Jest | `import { describe, it, expect } from '@jest/globals'` | `jest` |
| Mocha + Chai | `import { expect } from 'chai'` | `mocha` |

If no test framework detected, recommend Vitest and generate setup.

## Generation Rules

1. Follow existing test patterns in the codebase
2. One test file per source file (colocated)
3. Describe blocks mirror the function/component structure
4. Test the happy path first, then edge cases
5. Mock external dependencies (database, APIs)
6. Use factories for test data (not inline objects)

## Integration

Called between IMPLEMENT and SELF-HEAL:

```
Phase 3: IMPLEMENT (agent writes code)
Phase 3.5: TEST GEN (auto-generate tests)
Phase 4: SELF-HEAL (run tests — including generated ones)
```

## Coverage Tracking

After tests run, capture coverage delta:

```
Coverage before story: 72%
Coverage after story: 76%
Delta: +4%
```

Save to token-ledger alongside cost data.

## Test Templates

### Unit Test

```typescript
import { describe, it, expect } from "vitest"
import { functionName } from "../src/module"

describe("functionName", () => {
  it("should handle the happy path", () => {
    const result = functionName(validInput)
    expect(result).toEqual(expectedOutput)
  })

  it("should handle edge cases", () => {
    expect(() => functionName(null)).toThrow()
    expect(functionName("")).toEqual(defaultValue)
  })
})
```

### API Integration Test

```typescript
import { describe, it, expect } from "vitest"

describe("POST /api/resource", () => {
  it("should create a resource", async () => {
    const res = await fetch("/api/resource", {
      method: "POST",
      body: JSON.stringify({ name: "test" }),
    })
    expect(res.status).toBe(201)
  })

  it("should reject invalid input", async () => {
    const res = await fetch("/api/resource", {
      method: "POST",
      body: JSON.stringify({}),
    })
    expect(res.status).toBe(400)
  })
})
```

## Output Contract

```yaml
output_contract:
  file_pattern: "**/*.test.{ts,tsx,js,jsx}"
  required_content:
    - "describe("
    - "it(" or "test("
    - "expect("
  min_tests_per_file: 2
```
