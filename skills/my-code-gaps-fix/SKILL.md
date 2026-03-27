---
name: my-code-gaps-fix
description: Use when you want to find and fix gaps in the codebase — dispatches all agent personalities to audit code against CLAUDE.md guardrails and acceptance criteria, documents gaps with fix suggestions, then implements fixes. Also use for "audit the code", "find gaps", or "check against criteria".
argument-hint: "< security | services/api | frontend | (no arg: full audit) >"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent
---

# Code Gaps — Find and Fix

**Announce at start:** "I'm using the my-code-gaps-fix skill to audit the codebase against guardrails and fix what's found."

## Why This Skill Exists

Code drifts from its own rules. Acceptance criteria are defined upfront but implementations cut corners under time pressure — or the criteria existed after the code was written. CLAUDE.md guardrails state what correct code looks like, but nobody checks whether existing code meets them. This skill enforces that check and closes the loop by actually fixing what it finds.

**The difference from /my-review-docs:** That skill audits planning documents before implementation. This skill audits the running codebase after implementation — it reads real code, not plans.

---

## Step 0: Resolve Project Root

Before any file operations, resolve the git repo root. All project-relative paths (`docs/`, `.claude/`, `state.md`) are relative to this root, NOT `pwd`.

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
```

## Step 1: Load the guardrails

Read both reference documents before dispatching any agents:

1. `~/.claude/CLAUDE.md` — global correctness rules, anti-sycophancy, scope limits
2. `docs/build/acceptance-criteria.md` — project-specific measurable criteria (if it exists)

If `docs/build/acceptance-criteria.md` does not exist, note it prominently and use CLAUDE.md alone as the standard.

Extract and summarize the active rules. These become the pass/fail criteria for the audit.

---

## Step 2: Discover the codebase scope

Map the codebase:

```
services/api/    — FastAPI backend
apps/studio/     — Studio Next.js app
apps/console/    — Console Next.js app
apps/website/    — Marketing site Next.js app
apps/csites/     — Tenant sites Next.js app
```

If the user passed a scope argument (e.g., "services/api" or "security only"), restrict the agents to that scope.

---

## Step 3: Dispatch parallel audit agents

Dispatch FIVE agents in parallel. Each agent reads its personality file, then audits the real code against the guardrails loaded in Step 1.

**Agent 1 — Code Reviewer**
- Load identity: `~/.claude/agents/reviewers/code.md`
- Scope: all backend Python code in `services/api/app/`
- Check against the 7 review dimensions (correctness, security, error handling, concurrency, complexity, algorithm, test coverage)
- Specifically check against any acceptance criteria thresholds (performance targets, test coverage requirements, LOC limits)
- Return: flat list of findings with file:line references, severity (BLOCK / WARN / NOTE), and suggested fix for each

**Agent 2 — Security Reviewer**
- Load identity: `~/.claude/agents/reviewers/security.md`
- Scope: all code that handles user input, auth, DB queries, external webhooks, or file paths
- Apply the full OWASP A1–A10 checklist against the actual code
- Pay specific attention to: multi-tenant isolation (is tenant_id always from session, never from user input?), parameterized queries, webhook signature verification, rate limiting presence
- Return: findings in Security Reviewer format (Critical/High/Medium), each with file:line and specific fix

**Agent 3 — Architect**
- Load identity: `~/.claude/agents/specialists/architect.md`
- Scope: the full codebase structure — how modules relate, where business logic lives, DB query patterns
- Check: N+1 query patterns, business logic in wrong layers, unbounded in-memory structures, background jobs without durable state
- Return: findings in Architect format, each with file references and recommended change

**Agent 4 — Platform Engineer**
- Load identity: `~/.claude/agents/specialists/platform.md`
- Scope: `services/api/app/main.py`, all cron/scheduler code, docker-compose files, migration files, any config or health check code
- Check: health check endpoints exist, services restart on crash, cron jobs use durable scheduler, log rotation configured, DB pool sized correctly
- Return: findings in Platform Engineer format (Critical/High/Medium), each with file:line and fix

**Agent 5 — Frontend Engineer**
- Load identity: `~/.claude/agents/specialists/frontend.md`
- Scope: all Next.js apps — `apps/studio/`, `apps/website/`, `apps/csites/`
- Check: `use client` overuse, missing image optimization, JS animations that should be CSS, missing lazy loading, bundle size red flags, React re-render patterns
- Return: findings in Frontend Engineer format (Critical/High/Medium), each with file:line and specific fix

---

## Step 4: Triage the findings

Collect all findings from all 5 agents. Categorize each finding:

**Fixable now** — code change, no architectural decision needed, no migration required, no external dependency
- Examples: missing parameterized query, unwrapped external call, missing auth check, inefficient loop, missing `restart: unless-stopped`, CSS animation that should use transforms

**Requires decision** — fixing it requires a choice that should not be made automatically
- Examples: N+1 query that requires a schema change, architectural boundary violation, adding a new dependency

**Requires human action** — cannot be fixed in code
- Examples: missing environment variable, Stripe dashboard configuration, DNS record, untested backup restore

For each "Fixable now" finding, write the exact fix as a code diff or replacement snippet. For others, document the decision needed or the human action required.

---

## Step 5: Write the gap report

Write `docs/code-gaps-YYYY-MM-DD.md` (use today's date):

```markdown
# Code Gaps Report — [date]

> Generated by /my-code-gaps-fix. Audited against ~/.claude/CLAUDE.md and docs/build/acceptance-criteria.md.

## Summary
- Files audited: [N]
- Total findings: [N] critical, [N] high, [N] medium, [N] low
- Fixable now: [N] (will be fixed in this session)
- Requires decision: [N] (documented below, not auto-fixed)
- Requires human action: [N] (documented below)

---

## Findings Fixed in This Session

| # | File | Line | Agent | Issue | Fix Applied |
|---|------|------|-------|-------|-------------|

---

## Requires Decision (not auto-fixed)

For each: what the gap is, what decision is needed, what the options are, recommended option with rationale.

---

## Requires Human Action

For each: what is missing, what exact action to take, where to do it.

---

## Per-Agent Full Reports

### Code Reviewer
[full output]

### Security Reviewer
[full output]

### Architect
[full output]

### Platform Engineer
[full output]

### Frontend Engineer
[full output]
```

---

## Step 6: Fix the fixable gaps

For every finding categorized as "Fixable now":

1. State the file and line being changed
2. State the gap being closed (which guardrail or acceptance criterion it violates)
3. Apply the fix using Edit or Write
4. Do NOT over-engineer fixes — the fix should be the minimal change that closes the gap, nothing more
5. Do NOT refactor surrounding code while fixing — scope each change tightly

After all fixes are applied, run the existing test suite:

```bash
cd services/api && python -m pytest tests/ -v
```

If any test fails due to a fix, investigate and correct immediately. Do not leave a broken test suite.

---

## Step 7: Print summary

Output:
1. Total findings by severity
2. Number fixed vs. deferred
3. Top 3 most important unfixed findings (for the user to decide on)
4. Path to the gap report
5. Whether the test suite is green

---

## Gotchas

- Running without acceptance-criteria.md produces vague findings — always run /my-create-acceptance-criteria first
- Agent personalities may disagree on the same gap — the referee personality should arbitrate, not majority vote

## Rules

- Never fix a "Requires decision" gap without the user's input. Document it and stop.
- Never fix a gap by adding tests that assert the wrong behavior — fix the behavior.
- Minimal fix scope: do not refactor while fixing. One gap, one change.
- If a fix would require adding a new dependency, flag it for decision instead.
- After fixing, always verify the test suite still passes before claiming the fix is complete.
- If the codebase has no acceptance criteria doc, note it in the report but still audit against CLAUDE.md guardrails.
- Confidence levels: state high/medium/low on every non-trivial finding. Uncertain findings go in "Requires decision" not "Fixable now."

## Quick Help

**What**: Dispatches 5 agent personalities to audit code against CLAUDE.md guardrails and acceptance criteria, then auto-fixes what it can.
**Usage**:
- `/my-code-gaps-fix` — full codebase audit
- `/my-code-gaps-fix security` — focus on security gaps only
- `/my-code-gaps-fix services/api` — scope to a directory
**Output**: `docs/code-gaps-YYYY-MM-DD.md` with findings split into "Fixable now" (auto-fixed) and "Requires decision" (flagged).
**Agents used**: Code Reviewer, Security Reviewer, Architect, Platform Engineer, Frontend Engineer.
