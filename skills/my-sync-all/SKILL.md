---
name: my-sync-all
description: Use when you want to update all projects at once — runs git pull on all active project repos and syncs claude-config. Also use for "sync everything", "update all projects", or "pull all repos".
argument-hint: "< commit message | (no arg: auto-message) >"
allowed-tools: Bash(bash:*)
---

# Sync All

Auto-discovers all git repos in `~/code/github/` (top-level only, excluding claude-config), runs git update on each, then runs claude-config bidirectional sync and pushes claude-config itself.

## Steps

1. **Run** — execute the sync-all script:
   ```bash
   bash "$HOME/code/github/claude-config/sync-all.sh" [user arguments if any]
   ```
   If the user passed arguments, forward them as the commit message.
2. **Report** — show the script output. Summarize: which repos had changes, which were clean, any failures.
3. **Failures** — if any repos failed, explain why and suggest manual resolution (e.g., rebase conflicts need `cd <repo> && git status`).

## Gotchas

- Repos with uncommitted changes will fail on git pull — stash or commit first
- Repos on non-main branches won't be updated — only pulls the current branch

## Rules

- Always run with `bash` explicitly
- Do not modify the sync-all script itself
- If a repo has rebase conflicts, the script aborts that repo — tell the user to resolve manually
- If the script itself is missing, tell the user to pull claude-config: `git -C "$HOME/code/github/claude-config" pull`

## Quick Help

**What**: Git pull --rebase all active project repos under `~/code/github/`, then sync and push claude-config.
**Usage**:
- `/my-sync-all` — updates all repos
- `/my-sync-all updated skills` — custom commit message for claude-config
**Skips**: claude-config (handled separately at end). Reports per-repo status.
