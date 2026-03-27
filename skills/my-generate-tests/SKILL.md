---
name: my-generate-tests
description: Use when existing code lacks tests — analyzes functions, branches, and edge cases then generates comprehensive test suites. Also use for "write tests", "add test coverage", "generate tests for this", or "backfill tests".
argument-hint: "< file path | directory | function name >"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(npx:*), Bash(pytest:*), Bash(node:*), Bash(python3:*), Bash(go:*), Bash(cargo:*), Agent
---

# Generate Tests for Existing Code

Analyze existing code and generate comprehensive test suites covering happy paths, edge cases, error paths, and boundary conditions.

## Quick Help

**What**: Backfill tests for code that doesn't have them. Analyzes branches, edge cases, and error paths.
**Usage**:
- `/my-generate-tests src/lib/auth.ts` — generate tests for a specific file
- `/my-generate-tests src/api/` — generate tests for all files in a directory
- `/my-generate-tests handlePayment` — find and test a specific function
**Output**: Test files written next to source files (or in the project's test directory), following existing test conventions.
**Note**: Does NOT replace TDD for new code. Use superpowers:test-driven-development for that. This is for backfilling tests on existing, untested code.

## Step 0: Resolve Project Root

Before any file operations, resolve the git repo root. All project-relative paths are relative to this root, NOT `pwd`.

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
```

## Steps

### 1. Detect Test Framework and Conventions

Before writing any tests, discover:

| What | How |
|------|-----|
| Language | File extension of target |
| Test framework | Check `package.json` (jest/vitest/mocha), `pyproject.toml` (pytest), `Cargo.toml`, `go.mod` |
| Test location | Glob for existing `*.test.*`, `*.spec.*`, `*_test.*`, `test_*.*`, `tests/` directory |
| Test style | Read 1-2 existing test files to match: naming, imports, assertion style, setup/teardown patterns |
| Coverage config | Check for jest.config, vitest.config, pytest.ini, .coveragerc |

If no test framework is configured, ask the user which to use. Do not install one without asking.

### 2. Analyze the Target Code

For each file/function to test:

1. **Map all branches** — if/else, switch/case, try/catch, early returns, ternary operators, optional chaining fallbacks
2. **Identify inputs** — function parameters, environment variables, global state, database queries, API calls
3. **Identify outputs** — return values, side effects (DB writes, API calls, file writes, events emitted)
4. **List edge cases**:
   - Empty/null/undefined inputs
   - Boundary values (0, -1, MAX_INT, empty string, empty array)
   - Type coercion traps (0 vs false, "" vs null)
   - Concurrent access patterns
   - Error paths (network failure, timeout, invalid data)
5. **Identify external dependencies** — what needs mocking vs what should use real implementations
   - Prefer real implementations for pure logic
   - Mock only: network calls, file system, time/date, external services
   - Never mock the thing you're testing

### 3. Generate Test Structure

For each function/module, generate tests in this priority order:

```
describe('<module or function>')
  describe('happy path')
    - test with typical valid input → expected output
    - test with minimal valid input → expected output

  describe('edge cases')
    - test with empty input
    - test with boundary values
    - test with special characters / unicode

  describe('error paths')
    - test with invalid input → expected error
    - test with missing required fields
    - test with external service failure (mocked)

  describe('concurrency') [if applicable]
    - test with concurrent calls
    - test idempotency

  describe('integration') [if applicable]
    - test with real dependencies (DB, filesystem)
```

### 4. Write Tests

- Write test file following the project's existing naming convention
- Match the existing test style exactly (imports, describe/it vs test, assertion library)
- Each test must have a descriptive name that states the scenario and expected outcome
- Each test must assert on specific values, not just "doesn't throw"
- Do NOT test implementation details (private methods, internal state) — test behavior

### 5. Run and Verify

Run the generated tests:
- All tests should PASS (we're testing existing, working code)
- If a test fails, the test is wrong (not the code) — fix the test
- Report coverage delta if coverage tooling is available

### 6. Output Summary

```
## Tests Generated

| File | Tests | Branches Covered | Edge Cases | Notes |
|------|-------|-----------------|------------|-------|

## What's NOT Tested (and why)
- [scenario]: [reason — e.g., requires live DB, needs auth token, non-deterministic]

## Coverage Delta
- Before: [X]%
- After: [Y]%
- Remaining gaps: [list]
```

## Gotchas

- Generated tests may import from wrong paths if the project uses path aliases (tsconfig paths, webpack aliases)
- Tests for async code often miss race conditions — generated tests tend to test the happy path only
- Mock-heavy tests pass but mask real integration bugs — prefer integration tests where possible

## Rules

- **This is for existing code only** — for new code, use TDD via superpowers:test-driven-development
- **Match existing conventions exactly** — if the project uses `vitest` + `describe/it`, don't generate `jest` + `test()`
- **Never mock the thing under test** — mock dependencies, not the subject
- **Tests must pass** — if a generated test fails against working code, the test is wrong
- **Prefer real over mocked** — only mock external I/O (network, filesystem, time)
- **No snapshot tests unless the project already uses them** — snapshots are brittle
- **Assert on behavior, not implementation** — "returns X" not "calls Y internally"
- **One assertion per test when practical** — makes failures easier to diagnose
- **Don't test trivial code** — getters, setters, pass-through functions don't need tests
- **Do test error paths** — these are where most production bugs hide
