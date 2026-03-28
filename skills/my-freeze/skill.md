---
name: my-freeze
description: Use when the user wants to restrict edits to a specific directory — blocks Edit/Write operations outside the allowed path. Invoke as "/my-freeze src/components" to lock edits to that directory only. Use "/my-freeze off" to deactivate.
argument-hint: "< directory path | off >"
---

# /my-freeze — Directory-scoped Edit Lock

Restricts all file edits (Edit, Write tools) to a specific directory. Any attempt to modify files outside the frozen directory is blocked by a PreToolUse hook.

## Activation

When the user invokes `/my-freeze <directory>`:

1. Resolve the directory to an absolute path relative to the current working directory.
2. Write the absolute path to `/tmp/claude-freeze-dir.flag`.
3. Announce:

```
Freeze mode ON — edits restricted to: <absolute-path>
Any Edit or Write outside this directory will be blocked.
Run /my-freeze off to deactivate.
```

```bash
echo "/absolute/path/to/dir" > /tmp/claude-freeze-dir.flag
```

## Deactivation

When the user invokes `/my-freeze off` or `/my-freeze` with no arguments while already active:

```bash
rm -f /tmp/claude-freeze-dir.flag
```

Announce:
```
Freeze mode OFF — edits allowed everywhere.
```

## What Gets Blocked

The hook at `~/.claude/hooks/freeze-guard.sh` checks Edit and Write tool calls when the flag file exists:

- Reads the allowed directory from the flag file
- Extracts `file_path` from the tool input JSON
- If the file path does NOT start with the allowed directory prefix → **BLOCKED**
- If the file path starts with the allowed directory → **ALLOWED**

## Gotchas

- Bash `Write` via redirects (`echo > file`) is NOT blocked — only the Edit and Write tools are guarded
- Symlinks can bypass the prefix check — if `/tmp/link` points to `/etc/`, editing `/tmp/link/passwd` would be allowed if `/tmp/` is the frozen dir
- Only one freeze directory at a time — invoking `/my-freeze` with a new dir replaces the old one silently

## Examples

- `/my-freeze src/api` → only files under `<cwd>/src/api/` can be edited
- `/my-freeze .` → only files under the current working directory (still useful to prevent editing ~/.claude/ or other system files)
- `/my-freeze ~/code/github/my-project-2/services/api` → absolute path, edits only in my-project-2's API service

## Rules

- Only one freeze directory at a time (new freeze replaces old)
- The hook checks both Edit and Write tools (not Bash — Bash can still create files via redirects, but that's intentional for scripts)
- If the user needs to edit a file outside the freeze, they must deactivate first
- Always show the resolved absolute path so there's no ambiguity
- Do not silently deactivate — always announce state changes
