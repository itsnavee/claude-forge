---
name: my-pr-review
description: Use when a PR needs thorough review — dispatches 6 specialized agents (silent failures, type design, simplification, test gaps, comment analysis, general review) in parallel. Also use for "review this PR", "review PR #123", or "deep review".
argument-hint: "< PR number | branch name | file paths >"
allowed-tools: Read, Glob, Grep, Bash(git:*), Bash(gh:*), Agent
gate:
  type: cooldown
  duration: 10m
  reason: "Dispatches 6 parallel agents. Re-running on the same PR without new commits produces identical findings."
---

# Specialized PR Review

Dispatch 6 focused review agents against a PR or set of changes. Each agent catches a different class of bug that generalist reviewers miss.

## Quick Help

**What**: Deep PR review using 6 specialized agents in parallel — finds silent failures, type design flaws, dead code, test gaps, and more.
**Usage**:
- `/my-pr-review 42` — review PR #42
- `/my-pr-review feature/auth` — review current branch vs main
- `/my-pr-review src/api/ src/lib/` — review specific paths
**Output**: Consolidated findings table sorted by severity (BLOCK > WARN > NOTE), deduplicated across agents.

## Steps

### 1. Gather the Diff

Determine what to review based on argument:

| Argument | How to Get Diff |
|----------|----------------|
| PR number | `gh pr diff <number>` and `gh pr view <number> --json files` |
| Branch name | `git diff main...<branch> --stat` then read changed files |
| File paths | Read the specified files + `git diff` for those paths |
| No argument | `git diff main...HEAD --stat` (current branch vs main) |

List all changed files. Read the full content of each changed file (not just the diff — agents need context).

### 2. Dispatch 6 Agents in Parallel

Launch all 6 as parallel subagents. Each gets the same file list and diff but a different focus.

**Agent 1 — Silent Failure Hunter**
> Review these changed files for silent failures: exceptions caught and swallowed, error branches that return success, promises that aren't awaited, callbacks that ignore error parameters, try/catch blocks that log but don't rethrow or handle, HTTP calls that don't check status codes, database operations that don't verify row counts. For each finding: file, line, the silent failure mechanism, and what could go wrong in production.

**Agent 2 — Type Design Analyzer**
> Review these changed files for type design issues: overly broad types (any, unknown, Object), missing discriminated unions where needed, type assertions (as/!) that bypass safety, interfaces that should be narrower, generic parameters that aren't constrained, return types that leak implementation details, nullable fields that should be required or vice versa. For each finding: file, line, the type issue, and the suggested fix.

**Agent 3 — Code Simplifier**
> Review these changed files for unnecessary complexity: abstractions used only once, wrapper functions that add no value, indirection that obscures logic, patterns that could be replaced with a simpler approach, dead code paths, redundant null checks, over-parameterized functions, classes that should be functions, DRY violations where copy-paste would be clearer. For each finding: file, line, what's complex, and the simpler alternative.

**Agent 4 — Test Gap Analyzer**
> Review these changed files and their corresponding test files. Identify: untested branches, missing edge case tests (empty input, null, boundary values, concurrent access), tests that assert on mocks instead of behavior, tests that would pass even if the code were wrong, missing integration tests for cross-module interactions, error paths with no test coverage. For each gap: file, the untested scenario, and a one-line test description.

**Agent 5 — Comment & Documentation Analyzer**
> Review these changed files for documentation issues: comments that contradict the code, TODOs with no tracking, outdated JSDoc/docstrings after signature changes, misleading function/variable names, public APIs with no documentation, magic numbers/strings with no explanation, README sections invalidated by these changes. For each finding: file, line, the issue.

**Agent 6 — General Code Reviewer**
> Load the ~/.claude/agents/reviewers/code.md identity and review these changed files across all 7 dimensions (correctness, security, error handling, concurrency, complexity, performance, test gaps). Output in the standard code-reviewer verdict format.

### 3. Consolidate Findings

Collect all 6 agent outputs. Deduplicate — if two agents flag the same line, keep the more specific finding.

Sort by severity:
1. **BLOCK** — must fix before merge
2. **WARN** — should fix, but not a blocker
3. **NOTE** — informational, up to the author

### 4. Output Format

```
## PR Review: [title or branch]
Files reviewed: [count] | Agents: 6/6 complete

### BLOCK ([count])
| # | File:Line | Agent | Finding | Fix |
|---|-----------|-------|---------|-----|

### WARN ([count])
| # | File:Line | Agent | Finding | Fix |
|---|-----------|-------|---------|-----|

### NOTE ([count])
| # | File:Line | Agent | Finding | Fix |
|---|-----------|-------|---------|-----|

### Verdict
[BLOCK / FIX SOON / SHIP WITH CAVEATS — based on highest severity finding]

### What Could Still Be Wrong
- [things agents couldn't verify without running the code]
```

## Gotchas

- 6 parallel agents consume significant tokens — consider using haiku for the simpler checks (comment analysis, type design)
- Large PRs (>500 lines changed) produce shallow reviews — scope to specific files if the diff is too large

## Rules

- All 6 agents run in parallel — do not wait for one before launching the next
- Each agent gets the FULL file contents, not just diffs — context matters
- General Code Reviewer (Agent 6) uses the existing code-reviewer.md identity
- Never say "looks good" — report what was checked and what couldn't be verified
- If the diff is >50 files, ask the user which paths to focus on
- Deduplicate aggressively — same file+line from multiple agents = one finding
