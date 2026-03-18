---
name: error-catalog
description: "Known error patterns with fix templates for the dev-loop self-heal phase. Enables targeted fixes instead of generic fixer agent dispatches."
---

# Error Catalog

Known error patterns encountered during the dev-loop self-heal phase. Each entry has a signature pattern, root cause, and targeted fix template. The dev-loop matches errors against this catalog before dispatching the fixer agent, enabling leaner T4 context.

## How to Use

During the SELF-HEAL phase:

1. Capture the error output from tsc, lint, or tests
2. Match against the patterns below (check signature regex)
3. If matched, use the fix template instead of dispatching a generic fixer
4. If no match, fall back to the standard fixer agent dispatch

## TypeScript Errors

### TS2304: Cannot find name

**Signature:** `error TS2304: Cannot find name '(\w+)'`
**Root cause:** Missing import or undeclared variable
**Fix template:**
1. Search the codebase for the export of the missing name
2. Add the import statement at the top of the file
3. If the name doesn't exist anywhere, it may need to be created

### TS2322: Type assignment error

**Signature:** `error TS2322: Type '(.+)' is not assignable to type '(.+)'`
**Root cause:** Type mismatch between value and expected type
**Fix template:**
1. Read the interface/type definition for the target type
2. Check if the value needs casting, transformation, or the type needs updating
3. If it's a missing property, add it. If it's an extra property, remove it or extend the type.

### TS2339: Property does not exist

**Signature:** `error TS2339: Property '(\w+)' does not exist on type '(.+)'`
**Root cause:** Accessing a property that isn't defined on the type
**Fix template:**
1. Check if the property exists on a related type (maybe wrong variable)
2. Check if the type needs to be extended
3. Check if optional chaining is needed (`?.`)

### TS2345: Argument type mismatch

**Signature:** `error TS2345: Argument of type '(.+)' is not assignable to parameter of type '(.+)'`
**Root cause:** Function called with wrong argument type
**Fix template:**
1. Read the function signature to understand expected types
2. Transform the argument or update the function signature

### TS7006: Parameter implicitly has 'any' type

**Signature:** `error TS7006: Parameter '(\w+)' implicitly has an 'any' type`
**Root cause:** Missing type annotation in strict mode
**Fix template:**
1. Determine the correct type from usage context
2. Add explicit type annotation

### TS2307: Cannot find module

**Signature:** `error TS2307: Cannot find module '(.+)'`
**Root cause:** Missing dependency or wrong import path
**Fix template:**
1. Check if it's a package import → may need `npm install`
2. Check if it's a local import → verify path, file extension, index file
3. Check tsconfig paths for aliases

## ESLint / Linter Errors

### Unused variable

**Signature:** `'(\w+)' is (defined|assigned|declared) but never used`
**Root cause:** Variable declared but not referenced
**Fix template:**
1. If intentionally unused (e.g., destructuring), prefix with `_`
2. If accidentally unused, remove the declaration
3. If it should be used, find where it was meant to be used

### Missing semicolon / trailing comma

**Signature:** `(Missing semicolon|Unexpected trailing comma|Extra semicolon)`
**Root cause:** Style rule violation
**Fix template:**
1. Apply the project's style convention (check prettier/eslint config)
2. Run the formatter if available

### Import order

**Signature:** `Import .* should occur (before|after) import`
**Root cause:** Imports not in the project's preferred order
**Fix template:**
1. Reorder imports according to project convention
2. Run the import sorter if configured

### React hooks rules

**Signature:** `React Hook .* (is called conditionally|cannot be called inside a callback)`
**Root cause:** Hook called outside component/hook top level
**Fix template:**
1. Move the hook call to the component/hook's top level
2. If conditional logic is needed, restructure using early returns

## Test Failures

### Assertion failure

**Signature:** `(expect\(.*\)\.(toBe|toEqual|toMatch)|AssertionError)`
**Root cause:** Test expectation doesn't match actual value
**Fix template:**
1. Read the test to understand what's expected
2. Check if the implementation is wrong (fix implementation)
3. Check if the test expectation is outdated (update test)
4. Prefer fixing implementation over updating tests

### Timeout

**Signature:** `(Timeout|exceeded .* timeout|Async callback was not invoked)`
**Root cause:** Async operation not resolving
**Fix template:**
1. Check for missing `await` on async calls
2. Check for unresolved promises
3. Check for missing mock responses in test setup
4. Increase timeout if the operation is genuinely slow

### Module not found in test

**Signature:** `Cannot find module '(.+)' from '(.+\.test\.\w+)'`
**Root cause:** Test importing from wrong path or missing mock
**Fix template:**
1. Check if the import path changed (file was moved/renamed)
2. Check if a mock/stub is needed for the module
3. Check jest/vitest config for module name mapping

### Setup/teardown failure

**Signature:** `(beforeAll|beforeEach|afterAll|afterEach) .* (failed|threw)`
**Root cause:** Test setup or cleanup failing
**Fix template:**
1. Check database/service connections in setup
2. Check cleanup order (resources freed in wrong order)
3. Check for environment variables needed by setup

## Runtime Errors

### Cannot read property of undefined/null

**Signature:** `Cannot read propert(y|ies) of (undefined|null)`
**Root cause:** Accessing property on null/undefined value
**Fix template:**
1. Add null check before access
2. Check if the data source returns null (API, database query)
3. Add optional chaining (`?.`) or nullish coalescing (`??`)

### Connection refused

**Signature:** `(ECONNREFUSED|Connection refused|connect ECONNREFUSED)`
**Root cause:** Service not running or wrong port
**Fix template:**
1. Check if the required service is running (database, API)
2. Verify connection string/URL in config
3. Check if the port is correct

### Permission denied

**Signature:** `(EACCES|Permission denied|EPERM)`
**Root cause:** File system permission issue
**Fix template:**
1. Check file permissions on the target path
2. Check if the process has write access to the directory
3. Avoid writing to system directories

## Cascading Fix Strategy

When multiple errors occur:

1. **Sort by dependency:** Fix import/module errors first (they often cascade)
2. **Fix type errors second:** They often resolve after imports are fixed
3. **Fix lint errors third:** Style issues are lowest priority
4. **Re-run checks:** After each fix, re-run the failing check to see if cascading errors resolved

## Adding New Patterns

After encountering a new error pattern that was successfully fixed:

1. Add it to this catalog with signature, root cause, and fix template
2. The retrospective skill may suggest additions based on recurring patterns
3. Keep entries concise — the fix template should be actionable in 3 steps or fewer
