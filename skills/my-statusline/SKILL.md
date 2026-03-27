---
name: my-statusline
description: Use when you want to change the statusline display — switches between mini (compact), max (full), or none (disabled) modes. Also use for "change statusline", "compact status", or "hide statusline".
argument-hint: "< mini | max | none >"
user_invocable: true
args: "<mode: mini|max|none>"
---

# Statusline Mode Switcher

Switch between statusline display modes by updating `~/.claude/settings.json`.

## Modes

| Mode | Script | Description |
|------|--------|-------------|
| `mini` | `~/.claude/statusline-mini.sh` | MODEL, CONTEXT, NET+PWD, USAGE only |
| `max` | `~/.claude/statusline.sh` | Full statusline (weather, quotes, learning, env, memory) |
| `none` | *(removed)* | Statusline disabled |

## Execution

1. Parse the argument. If missing or invalid, show usage and ask which mode.
2. Read `~/.claude/settings.json`
3. Update the `statusLine` key:
   - **mini**: `{"type": "command", "command": "~/.claude/statusline-mini.sh"}`
   - **max**: `{"type": "command", "command": "~/.claude/statusline.sh"}`
   - **none**: remove the `statusLine` key entirely (or set to `null`)
4. Write back the file
5. Confirm: `Statusline set to <mode>. Restart Claude Code or start a new session to see the change.`

## Gotchas

- Statusline changes require the script at ~/.claude/statusline-mini.sh (or -max.sh) to exist
- Edits to the repo copy don't take effect — must also sync to ~/.claude/

## Important

- Use the Edit tool to modify settings.json — do NOT rewrite the whole file
- Preserve all other settings untouched
- The statusline scripts must already exist at the target paths (synced via claude-config-sync)
