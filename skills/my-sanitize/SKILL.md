---
name: my-sanitize
description: Use when preparing to push to a public repo — scans all files for sensitive patterns (project names, paths, emails, tokens) and fixes them. Also use for "sanitize", "check for sensitive data", "clean before push", or "scrub personal info".
argument-hint: "< check | fix | patterns | (no arg: check current repo) >"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(git:*), Bash(gh:*), Bash(grep:*), Bash(sed:*), Bash(cat:*), Bash(wc:*)
---

# Sanitize

Scan files in a public repo for sensitive patterns and fix them before pushing.

## Arguments

- No args: scan current repo, report violations
- `check`: same as no args — scan and report only
- `fix`: scan and auto-fix violations (replace with generic placeholders)
- `patterns`: show current patterns from `~/.claude/sanitize-patterns.conf`

## Step 1 — Verify Context

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
REMOTE_URL=$(git remote get-url origin 2>/dev/null)
OWNER_REPO=$(echo "$REMOTE_URL" | sed -E 's|.*github\.com[:/]([^/]+/[^/.]+)(\.git)?$|\1|')
VISIBILITY=$(gh repo view "$OWNER_REPO" --json visibility -q '.visibility' 2>/dev/null)
```

Print repo name and visibility. If private, warn: "This repo is private. Sanitize is designed for public repos. Continue anyway?"

## Step 2 — Load Patterns

Read `~/.claude/sanitize-patterns.conf`. Parse non-comment, non-blank lines as grep patterns.

If `patterns` argument: print the patterns file and exit.

## Step 3 — Scan

Scan **all tracked files** in the repo (not just staged):

```bash
git ls-files
```

For each pattern, grep across all tracked files. Report:

```
VIOLATION: pattern "my-project" found in:
  skills/my-save/SKILL.md:115  — `my-project-4`, `claude-forge`, `claude-config`
  hooks/session-summary.sh:25  — SKIP_REPOS=("claude-config" "second-brain" "my-project-6" "my-project-4" "my-project")
```

Skip binary files. Skip `.git/`.

### What to skip (false positives)

- `sanitize-patterns.conf` itself (it contains the patterns by definition)
- Lines that are comments explaining the pattern (e.g., `# my-project is a private project`)
- The `my-sanitize` skill file itself

## Step 4 — Fix (if `fix` argument)

For each violation, apply a replacement:

**Project names** → replace with generic: `my-project`, `my-store`, `my-app`, `my-infra`
**Personal paths** → replace `$HOME/` with `~/`, `$HOME/` with `~/`
**Email addresses** → replace with `your@email.com`
**Usernames** → replace with `your-username`

Use `Edit` tool for targeted replacements. Show each replacement before applying.

After fixing, re-run scan to verify zero violations remain.

## Step 5 — Summary

```
Sanitize Complete
  Repo: claude-forge (PUBLIC)
  Files scanned: 142
  Violations found: 7
  [check mode] Fixed: 0 — run /my-sanitize fix to auto-replace
  [fix mode] Fixed: 7 — review changes with git diff before pushing
```

## Gotchas

- Pattern matching is case-insensitive by default — a pattern `my-project` catches `SpeakLaunch` too
- The fix step uses generic placeholders — review the diff to ensure context still makes sense
- Binary files are skipped — check images/PDFs manually if they might contain text
- The `sanitize-patterns.conf` file itself is excluded from scanning (it defines the patterns)

## Quick Help

**What**: Scans public repo files for sensitive patterns (project names, paths, emails, tokens) and optionally fixes them.
**Usage**:
- `/my-sanitize` — scan current repo, report violations
- `/my-sanitize fix` — scan and auto-replace with generic placeholders
- `/my-sanitize patterns` — show current pattern list
**Config**: `~/.claude/sanitize-patterns.conf` — one pattern per line, comments with `#`
**Hook**: Auto-runs on `git push` to public repos via `sanitize-public-repo.sh` PreToolUse hook.
