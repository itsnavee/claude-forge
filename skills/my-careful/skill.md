---
name: my-careful
description: Use when about to do dangerous operations (deploys, database migrations, force pushes, production changes) — activates on-demand hook that blocks destructive commands. Also use when the user says "be careful", "careful mode", or wants extra safety. Use /my-careful again to deactivate.
argument-hint: "< on | off >"
---

# /my-careful — On-demand Destructive Command Blocker

Toggles a safety mode that blocks destructive commands via a PreToolUse hook. When active, commands matching dangerous patterns are rejected with an explanation.

## Behavior

- **First invocation**: Activates careful mode. Creates flag file at `/tmp/claude-careful-mode.flag`.
- **Second invocation**: Deactivates careful mode. Removes the flag file.
- Always announce the current state to the user.

## On Activation

```bash
touch /tmp/claude-careful-mode.flag
```

Tell the user:
```
Careful mode ON — destructive commands will be blocked.
Blocked patterns: rm -rf, git push --force, git reset --hard, DROP/TRUNCATE/DELETE without WHERE, docker system prune, kill -9, chmod 777, > /dev/null redirection of important files.
Run /my-careful again to deactivate.
```

## On Deactivation

```bash
rm -f /tmp/claude-careful-mode.flag
```

Tell the user:
```
Careful mode OFF — all commands allowed.
```

## Gotchas

- The flag file is at `/tmp/` so it survives within a session but gets cleared on reboot — careful mode won't persist across machine restarts
- Bash heredocs and piped commands can bypass pattern matching — the hook checks the top-level command string, not subshells
- `docker compose down` is NOT blocked (it's a normal shutdown) — only `docker system prune` is blocked
- SQL patterns only match literal strings — parameterized queries or ORMs won't trigger the guard

## What Gets Blocked

The hook at `~/.claude/hooks/careful-mode-guard.sh` checks for these patterns when the flag file exists:

| Pattern | Why |
|---------|-----|
| `rm -rf /` or `rm -rf ~` or `rm -rf .` | Catastrophic deletion |
| `git push --force` or `git push -f` | Overwrites remote history |
| `git reset --hard` | Discards uncommitted work |
| `git clean -fd` | Deletes untracked files |
| `git checkout -- .` or `git restore .` | Discards all changes |
| `DROP TABLE` / `DROP DATABASE` | Database destruction |
| `TRUNCATE` | Data loss |
| `DELETE FROM` without `WHERE` | Full table wipe |
| `docker system prune` | Removes all unused Docker data |
| `kill -9` | Ungraceful process kill |
| `chmod 777` | Insecure permissions |
| `mkfs` | Filesystem format |
| `dd if=` | Raw disk write |

## Rules

- This is a toggle — calling the skill again deactivates it
- The hook does NOT block when the flag file is absent (zero overhead when inactive)
- If the user explicitly says "I know what I'm doing, run it anyway", inform them to deactivate careful mode first with /my-careful
- Do not silently deactivate — always announce state changes
