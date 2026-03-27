---
name: my-incident-response
description: Use when there's a production incident or outage — structured triage, investigation, fix, verification, and postmortem. Also use for "site is down", "production issue", "incident", or "outage".
argument-hint: "< triage | investigate | fix | postmortem > [description]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(git:*), Bash(gh:*), Bash(curl:*), Bash(docker:*), Bash(kubectl:*), Bash(ssh:*), Bash(cat:*), Bash(tail:*), Bash(grep:*), Bash(ps:*), Bash(lsof:*), Agent
---

# Incident Response

Structured workflow for handling production incidents — from initial triage through investigation, fix, verification, and postmortem.

## Quick Help

**What**: Guided incident management with structured phases. Prevents panic-driven debugging.
**Usage**:
- `/my-incident-response triage Payment webhook returning 500 for Stripe test events` — quick severity assessment and initial response
- `/my-incident-response investigate` — deep-dive into root cause (assumes triage is done)
- `/my-incident-response fix` — implement and verify fix (assumes root cause is known)
- `/my-incident-response postmortem` — generate postmortem doc from git history and conversation
**Phases**: triage → investigate → fix → postmortem. Run them in sequence or jump to a specific phase.

## Step 0: Resolve Project Root

Before any file operations, resolve the git repo root. All project-relative paths (`docs/postmortems/`) are relative to this root, NOT `pwd`.

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
```

## Phase 1: Triage

**Goal**: Assess severity, determine blast radius, decide immediate response.

### Steps

1. **Gather signals** — ask the user or read available context:
   - What's broken? (endpoint, feature, service)
   - When did it start? (timestamp, deploy, config change)
   - Who's affected? (all users, one tenant, internal only)
   - What's the error? (status code, error message, stack trace)

2. **Classify severity**:

| Severity | Criteria | Response Time |
|----------|----------|---------------|
| **SEV-1** | Data loss, security breach, full outage | Drop everything. Fix now. |
| **SEV-2** | Major feature broken, significant user impact | Fix within hours. |
| **SEV-3** | Minor feature broken, workaround exists | Fix within 1-2 days. |
| **SEV-4** | Cosmetic, edge case, no user impact | Schedule normally. |

3. **Determine blast radius**:
   - How many users/tenants affected?
   - Is it getting worse? (cascading failure)
   - Are there dependent systems failing?

4. **Immediate response** (SEV-1/2 only):
   - Can we rollback? Check last deploy: `git log --oneline -5` and deploy history
   - Can we feature-flag it off?
   - Can we redirect traffic / fail to a fallback?
   - Do we need to notify users?

5. **Output triage summary**:
```
## Incident Triage
Severity: SEV-[N]
Started: [when]
Affected: [who/what]
Blast radius: [scope]
Immediate action: [rollback/flag/redirect/investigate]
```

## Phase 2: Investigate

**Goal**: Find the root cause. Don't guess — trace.

### Steps

1. **Timeline** — build a timeline of what happened:
   - Recent deploys: `git log --oneline --since="2 hours ago"`
   - Recent config changes
   - Recent dependency updates
   - External service status (check status pages if relevant)

2. **Trace the error path**:
   - Read error logs / stack traces
   - Find the failing code path: `grep -r "error message"` in source
   - Read the code around the failure point
   - Check if the code recently changed: `git log -p -- <file>`

3. **Form hypothesis** — state it explicitly:
   > "I believe the root cause is [X] because [evidence]. This would explain [symptoms] but NOT [other symptom if any]."

4. **Verify hypothesis**:
   - Can you reproduce locally?
   - Does the git blame show a recent change at the failure point?
   - Does reverting that change fix it?
   - Are there other instances of the same pattern that are also broken?

5. **If hypothesis is wrong**: form a new one. Do NOT fix something you don't understand.

6. **Output investigation summary**:
```
## Investigation
Timeline: [events leading to incident]
Root cause: [specific cause with evidence]
Hypothesis confidence: [high/medium/low]
Affected code: [file:line references]
```

## Phase 3: Fix

**Goal**: Implement the minimum fix, verify it works, and ship it.

### Steps

1. **Minimum viable fix** — fix the root cause with the smallest change possible:
   - No refactoring during incidents
   - No "while we're here" improvements
   - No dependency upgrades unless they ARE the fix

2. **Write a regression test** — a test that:
   - Fails without the fix
   - Passes with the fix
   - Covers the specific scenario that caused the incident

3. **Verify locally**:
   - Run the regression test
   - Run the full test suite
   - Manually test the affected workflow if possible

4. **Deploy and monitor**:
   - Commit with message: `fix: [incident description] — [root cause]`
   - Push and deploy
   - Watch logs/metrics for the specific error pattern
   - Confirm the error rate drops to zero

5. **Output fix summary**:
```
## Fix Applied
Change: [what was changed]
Files: [list]
Regression test: [test file:test name]
Verified: [how]
Deployed: [yes/no — commit hash]
```

## Phase 4: Postmortem

**Goal**: Document what happened, why, and what we'll do to prevent recurrence.

### Steps

1. **Gather data** from the conversation and git history
2. **Write postmortem** to `docs/postmortems/YYYY-MM-DD-<slug>.md`:

```markdown
# Postmortem: [Incident Title]
**Date**: [date]
**Severity**: SEV-[N]
**Duration**: [start] to [resolved]
**Author**: [user + Claude]

## Summary
[2-3 sentences: what happened, who was affected, how it was resolved]

## Timeline
| Time | Event |
|------|-------|
| [T+0] | [first symptom observed] |
| [T+Xm] | [investigation started] |
| [T+Xm] | [root cause identified] |
| [T+Xm] | [fix deployed] |
| [T+Xm] | [incident resolved] |

## Root Cause
[detailed technical explanation]

## Resolution
[what was done to fix it]

## Impact
- Users affected: [N]
- Duration of impact: [time]
- Data loss: [none/details]

## Lessons Learned
### What went well
- [thing that helped]

### What went wrong
- [thing that made it worse or delayed resolution]

## Action Items
| Action | Owner | Priority | Due |
|--------|-------|----------|-----|
| [prevent recurrence] | [who] | [P0/P1/P2] | [when] |
| [improve detection] | [who] | [P0/P1/P2] | [when] |
| [improve response] | [who] | [P0/P1/P2] | [when] |
```

## Gotchas

- Restarting a service before collecting logs destroys diagnostic state — always gather evidence first
- SSH access may be needed for remote servers — check connectivity before running diagnostic commands

## Rules

- **Never guess the root cause** — trace it with evidence. "I think it might be..." is not good enough.
- **Never make the incident worse** — if unsure about a fix, don't deploy it. Rollback instead.
- **Minimum viable fix** — no refactoring, no cleanups, no "improvements" during incident response
- **Always write a regression test** — if the incident can recur without a test catching it, the fix is incomplete
- **Blameless postmortems** — focus on systems and processes, not individuals
- **SEV-1/2: suggest rollback first** — a rollback that stops bleeding is better than a forward-fix that takes an hour
- Phase 4 (postmortem) should always be written, even for SEV-3/4 — it's how teams learn
