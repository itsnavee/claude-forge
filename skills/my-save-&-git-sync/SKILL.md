---
name: my-save-&-git-sync
description: Use when you want to save the session AND push changes in one command — runs /my-save then /my-git-sync sequentially. Also use for "save and push", "save and sync", or "wrap up and push".
argument-hint: "< commit message | (no arg: auto-message) >"
allowed-tools: Bash(git:*), Bash(gh:*), Read, Glob, Grep, Edit, Write
---

# Save & Git Sync

Run two skills in series without modifying either:

1. Read `~/.claude/skills/my-save/SKILL.md` and follow all its instructions completely. Pass any user-provided arguments as optional notes.
2. Once fully done, read `~/.claude/skills/my-git-sync/SKILL.md` and follow all its instructions completely. Pass any user-provided arguments as optional commit message context.

## Gotchas

- If /my-save fails midway, /my-git-sync still runs — may commit incomplete session data
- Double-check that state.md was updated correctly before the git sync pushes it

## Quick Help

**What**: Runs `/my-save` then `/my-git-sync` in sequence — saves session summary, then commits and pushes.
**Usage**:
- `/my-save-&-git-sync` — auto-generates everything
- `/my-save-&-git-sync added webhook handler` — uses as context for both save and commit message
