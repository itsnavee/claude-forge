---
name: my-hookify
description: Use when you need to manage hooks without editing settings.json — creates, lists, updates, or removes Claude Code hooks via natural language. Also use for "add a hook", "list hooks", "create hook for", or "remove hook".
argument-hint: "< create | list | remove | describe > [rule or hook name]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(cat:*), Bash(jq:*)
---

# Dynamic Hook Management

Create, list, update, or remove hooks from `~/.claude/settings.json` using natural language rules. No manual JSON editing.

## Quick Help

**What**: Manage Claude Code hooks without hand-editing settings.json.
**Usage**:
- `/my-hookify create block any curl to production URLs` — creates a PreToolUse hook with a matcher
- `/my-hookify list` — shows all active hooks with their matchers and scripts
- `/my-hookify remove post-edit-format` — removes a hook by ID
- `/my-hookify describe pre-git-add-guard` — explains what a hook does
**Safety**: Always backs up settings.json before writing. Never removes hooks it didn't create unless explicitly asked.

## Steps

### 1. Parse Intent

Determine the operation from the user's argument:
- **create** — new hook from a natural language rule
- **list** — display all hooks with their event, matcher, command, and purpose
- **remove** — delete a hook by name/ID
- **update** — modify an existing hook's command or matcher
- **describe** — explain what an existing hook does in plain English

If no operation is specified, default to **list**.

### 2. Read Current State

Read `~/.claude/settings.json` and extract the `hooks` object. Map the structure:
- Event types: `PreToolUse`, `PostToolUse`, `Stop`, `SessionStart`, `PreCompact`, `Notification`, `UserPromptSubmit`
- Each hook entry: `{ matcher, command, timeout? }`

### 3. For CREATE — Build the Hook

From the user's natural language rule, determine:

| Field | How to Derive |
|-------|--------------|
| **Event** | What triggers it? "before bash" → `PreToolUse`, "after edit" → `PostToolUse`, "on stop" → `Stop`, "on start" → `SessionStart` |
| **Matcher** | What tool does it match? "bash" → `Bash`, "edit" → `Edit`, "write" → `Write`. Leave empty for non-tool events. |
| **Command** | Write a shell script in `~/.claude/hooks/` that implements the rule. Use `$TOOL_INPUT` (PreToolUse) or `$TOOL_RESPONSE` (PostToolUse) for context. |
| **ID** | Derive a kebab-case ID from the rule: "block curl to production" → `block-curl-production` |

Script template for PreToolUse hooks:
```bash
#!/usr/bin/env bash
# Hook: [id]
# Rule: [natural language rule]
# Created: [date]

INPUT="$TOOL_INPUT"
# [validation logic]
# Exit 0 = allow, Exit 2 = block (with stderr as reason)
```

Script template for PostToolUse hooks:
```bash
#!/usr/bin/env bash
# Hook: [id]
# Rule: [natural language rule]
# Created: [date]

RESPONSE="$TOOL_RESPONSE"
# [post-processing logic]
```

After writing the script:
- `chmod +x` the script
- Add the hook entry to `settings.json` under the correct event
- Verify JSON is valid with `jq .` before writing

### 4. For REMOVE — Safe Deletion

- Find the hook in `settings.json` by matching the command path or a name/ID pattern
- Remove the entry from the hooks array
- Do NOT delete the script file (user may want to re-enable later)
- Verify JSON validity before writing

### 5. For LIST — Display All Hooks

Output a table:

```
| Event | Matcher | Hook ID | Script | Purpose |
|-------|---------|---------|--------|---------|
```

Include hooks from both `settings.json` and any scripts in `~/.claude/hooks/` that aren't configured (mark as "inactive").

### 6. For UPDATE — Modify In Place

- Read the existing hook script
- Apply the user's requested change
- Write back, preserving the original header comments
- Verify the updated script is syntactically valid with `bash -n`

## Gotchas

- Hook commands with spaces in paths need quoting in settings.json — the JSON serialization may break paths
- Adding a hook to a matcher that already has hooks appends to the array — it doesn't replace

## Rules

- **Always backup** — before any write to settings.json, copy to `settings.json.bak`
- **Validate JSON** — always pipe through `jq .` before writing settings.json
- **Validate scripts** — always run `bash -n` on hook scripts before marking done
- **Respect hook-gate** — include `ECC_HOOK_PROFILE` and `ECC_DISABLED_HOOKS` checks in generated scripts by sourcing `hook-gate.sh` if it exists
- **Never touch hooks you didn't create** unless the user explicitly names them
- **Keep scripts minimal** — hooks run on every tool call; they must be fast (<100ms)
- **Exit codes matter** — PreToolUse: 0=allow, 2=block (stderr shown to user). Document this in every generated script.
