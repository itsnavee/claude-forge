---
name: my-git-sync
description: Use when you need to commit and push changes — stages files, commits with co-author tags, pulls with rebase, resolves conflicts, and pushes. Also supports "pr" mode for creating PRs and "clean" mode for pruning merged branches. Also use for "commit", "push", "sync", or "create PR".
argument-hint: "< commit message | pr | clean >"
allowed-tools: Bash(git:*), Bash(gh:*), Read, Glob, Grep, Edit
---

# Git Sync (commit, pull, push + PR + cleanup)

Stage all changes, commit, pull with rebase, resolve any conflicts, and push. Optionally create a PR or clean up merged branches.

## Steps

### 0. Parse Mode

| Argument | Mode |
|----------|------|
| `pr` or `pr: <title>` | Full sync + create PR against main |
| `clean` | Prune local branches already merged into main |
| Anything else or empty | Standard sync (commit, pull, push) |

### 1. Assess
Run `git status` (never `-uall`) and `git diff --stat` to understand what changed.

### 2. Stage
Add relevant files by name (NEVER `git add .` or `git add -A`). Never stage `.env`, credentials, secrets, `node_modules/`, `dist/`, `build/`, `.next/`, or other build artifacts. Warn if any are present.

### 3. Commit
Draft a concise commit message (1-2 sentences, "why" not "what"). If the user passed arguments, use them as the message or context.

**Co-author lines depend on repo visibility.** Before committing, check if the repo is public:
```bash
source ~/.claude/hooks/is-public-repo.sh
```

- **Public repos** (`IS_PUBLIC_REPO=yes`):
```
Co-Authored-By: naveed.ahmed <5332157+youruser@users.noreply.github.com>
Co-Authored-By: Claude <noreply@anthropic.com>
```

- **Private repos** (`IS_PUBLIC_REPO=no`):
```
Co-Authored-By: naveed.ahmed <5332157+youruser@users.noreply.github.com>
Co-Authored-By: yourorg <247807559+youruser@users.noreply.github.com>
```

Use a HEREDOC for the message (example for private repo):
```bash
git commit -m "$(cat <<'EOF'
message here

Co-Authored-By: naveed.ahmed <5332157+youruser@users.noreply.github.com>
Co-Authored-By: yourorg <247807559+youruser@users.noreply.github.com>
EOF
)"
```

### 4. Pull Rebase
Run `git pull --rebase origin <current-branch>`.

### 5. Conflicts
If rebase conflicts occur:
- Read the conflicted files
- Resolve them sensibly (prefer incoming for non-overlapping, merge logic for overlapping)
- `git add <resolved-files>` then `git rebase --continue`
- Repeat until rebase completes

### 6. Push
Run `git push origin <current-branch>`.

### 7. (PR Mode) Create Pull Request
Only if the user passed `pr` or `pr: <title>`:
1. Determine the base branch (default: `main`)
2. Run `git log main..HEAD --oneline` to summarize commits
3. Create PR:
   ```bash
   gh pr create --title "<title>" --body "$(cat <<'EOF'
   ## Summary
   <bullet points from commit log>

   ## Test plan
   - [ ] ...

   Use the same public/private co-author logic as commits (step 3).
   EOF
   )"
   ```
4. Report the PR URL

### 8. (Clean Mode) Prune Merged Branches
Only if the user passed `clean`:
1. `git checkout main && git pull --rebase origin main`
2. List merged branches: `git branch --merged main | grep -v '^\*\|main\|master'`
3. Show the list and confirm with user before deleting
4. Delete confirmed branches: `git branch -d <branch>` (safe delete only, never `-D`)
5. Prune remote tracking: `git remote prune origin`
6. Report what was cleaned

### 9. Verify
Run `git status` to confirm clean state.

## Gotchas

- Pre-commit hooks that fail leave files staged but uncommitted — the next commit attempt may include unintended changes
- Rebase conflicts on binary files (images, fonts) can't be auto-resolved — stop and ask the user
- `git add` by specific filename can miss new files in subdirectories — always check `git status` after staging

## Rules

- Never use `--force` or `--no-verify`
- Never amend existing commits
- If pre-commit hooks fail, fix the issue, re-stage, and create a NEW commit
- If conflicts look too complex or risky, stop and ask the user
- Keep the summary at the end brief: commit hash, branch, pushed status
- Do NOT update or write session summary files after git sync completes — the save step already handled that
- **PR mode**: never create a PR from main to main. If on main, warn and stop.
- **Clean mode**: never use `git branch -D` (force delete). Only safe-delete merged branches. Always confirm the list with the user first.

## Quick Help

**What**: Stage, commit, pull --rebase, resolve conflicts, and push — all in one command. Plus PR creation and branch cleanup.
**Usage**:
- `/my-git-sync` — auto-generates commit message from diff
- `/my-git-sync fix auth redirect bug` — uses your text as commit message context
- `/my-git-sync pr` — full sync + create PR against main (auto-generates title from commits)
- `/my-git-sync pr: Add webhook signature verification` — full sync + create PR with custom title
- `/my-git-sync clean` — prune local branches already merged into main
**Safety**: Never stages `.env`/secrets/`node_modules`. Never force-pushes. Never amends. Resolves rebase conflicts or stops if too risky. Clean mode uses safe-delete only and confirms before removing.
**Co-authors**: Automatically adds Naveed + Claude co-author tags.
