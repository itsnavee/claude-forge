---
name: my-babysit-pr
description: Use when a PR needs monitoring — watches CI status, retries flaky tests, resolves merge conflicts, and optionally auto-merges when ready. Use when the user says "watch this PR", "babysit the PR", or "let me know when CI passes".
argument-hint: "< PR number | branch name >"
---

# /my-babysit-pr — Automated PR Monitoring

Monitors a PR's CI/CD status, handles common issues (flaky tests, merge conflicts), and reports when the PR is ready to merge.

## Behavior

### 1. Identify PR

Determine the PR to monitor:
- From argument: `/my-babysit-pr 123` or `/my-babysit-pr https://github.com/owner/repo/pull/123`
- From current branch: `gh pr view --json number,url`

### 2. Initial Status Check

```bash
gh pr view <number> --json title,state,mergeable,statusCheckRollup,reviews,headRefName,baseRefName
```

Report current state:
- PR title and branch
- CI status (passing/failing/pending)
- Review status (approved/changes requested/pending)
- Merge conflicts (yes/no)

### 3. Monitor Loop

Use `/loop 5m` to check every 5 minutes:

```bash
# Check CI status
gh pr checks <number> --json name,state,conclusion --jq '.[] | select(.state != "COMPLETED" or .conclusion != "SUCCESS")'

# Check mergeable status
gh pr view <number> --json mergeable --jq '.mergeable'
```

### 4. Handle Issues

**CI Failure — Flaky Test Detected:**
```bash
# Get failed check details
gh pr checks <number> --json name,conclusion,detailsUrl --jq '.[] | select(.conclusion == "FAILURE")'

# If the same test failed and passed on a previous run, it's flaky — re-run
gh run rerun <run-id> --failed
```

Report: "Re-running failed CI — `<test-name>` appears flaky (passed on previous run)."

**Merge Conflicts:**
```bash
# Attempt rebase
git fetch origin
git checkout <head-branch>
git rebase origin/<base-branch>
```

If conflicts are simple (non-overlapping):
- Resolve automatically
- Push the rebase
- Report: "Resolved merge conflicts in `<files>` and pushed."

If conflicts are complex (overlapping logic):
- Report: "Merge conflicts in `<files>` require manual resolution."
- Stop monitoring, ask the user to resolve.

**Review Requested:**
- Report: "PR awaiting review from `<reviewer>`."

### 5. Ready to Merge

When CI passes + reviews approved + no conflicts:

```
PR #<number> is ready to merge!
═══════════════════════════════
✓ CI: All checks passing
✓ Reviews: Approved
✓ Conflicts: None
✓ Mergeable: Yes

Merge? (waiting for your confirmation)
```

**Never auto-merge without explicit user confirmation.** Ask first.

If confirmed:
```bash
gh pr merge <number> --squash --delete-branch
```

## Gotchas

- `gh pr checks` can be empty if CI hasn't started yet — wait and retry before assuming failure
- Re-running CI (`gh run rerun`) requires write access to the repo
- Merge conflict resolution via rebase rewrites commits — only do this on feature branches, never on shared branches
- Some CI systems have rate limits on re-runs — don't retry more than twice
- `--squash` is the default merge strategy — if the repo uses merge commits or rebase, adapt

## Rules

- Never auto-merge — always ask the user for confirmation
- Never force-push during conflict resolution
- Maximum 2 CI retries for the same failure — after that, it's a real failure
- If conflicts involve more than 3 files or logic changes, stop and ask the user
- Report every state change (CI pass/fail, conflict detected, review status change)
- Stop monitoring if the PR is closed or merged externally
