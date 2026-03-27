#!/bin/bash
# ============================================================================
# Hook: Block destructive commands when careful mode is active
# Event: PreToolUse (matcher: Bash)
# Activated by: /careful skill (creates /tmp/claude-careful-mode.flag)
# Profile: standard,strict
# ============================================================================

source ~/.claude/hooks/hook-gate.sh
hook_gate "pre:bash:careful-mode" "standard,strict"

# Skip if careful mode is not active
[[ ! -f /tmp/claude-careful-mode.flag ]] && exit 0

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$COMMAND" ]] && exit 0

# Normalize: lowercase, collapse whitespace
CMD_LOWER=$(echo "$COMMAND" | tr '[:upper:]' '[:lower:]' | tr -s ' ')

# --- Destructive file operations ---
if echo "$CMD_LOWER" | grep -qE 'rm\s+-[a-z]*r[a-z]*f?\s+(/|~|\.)'; then
  echo '{"error": "BLOCKED [careful mode]: rm -rf on root/home/cwd. Deactivate with /my-careful if intentional."}'
  exit 2
fi

# --- Git destructive operations ---
if echo "$CMD_LOWER" | grep -qE 'git\s+push\s+(-f|--force)'; then
  echo '{"error": "BLOCKED [careful mode]: git push --force overwrites remote history. Deactivate with /my-careful if intentional."}'
  exit 2
fi
if echo "$CMD_LOWER" | grep -qE 'git\s+push\s+[^\s]+\s+\+'; then
  echo '{"error": "BLOCKED [careful mode]: git push with + prefix force-pushes. Deactivate with /my-careful if intentional."}'
  exit 2
fi
if echo "$CMD_LOWER" | grep -qE 'git\s+reset\s+--hard'; then
  echo '{"error": "BLOCKED [careful mode]: git reset --hard discards uncommitted work. Deactivate with /my-careful if intentional."}'
  exit 2
fi
if echo "$CMD_LOWER" | grep -qE 'git\s+clean\s+-[a-z]*f'; then
  echo '{"error": "BLOCKED [careful mode]: git clean -f deletes untracked files. Deactivate with /my-careful if intentional."}'
  exit 2
fi
if echo "$CMD_LOWER" | grep -qE 'git\s+(checkout|restore)\s+--?\s*\.'; then
  echo '{"error": "BLOCKED [careful mode]: discarding all changes. Deactivate with /my-careful if intentional."}'
  exit 2
fi

# --- Database destructive operations ---
if echo "$CMD_LOWER" | grep -qE 'drop\s+(table|database|schema)'; then
  echo '{"error": "BLOCKED [careful mode]: DROP statement. Deactivate with /my-careful if intentional."}'
  exit 2
fi
if echo "$CMD_LOWER" | grep -qE 'truncate\s'; then
  echo '{"error": "BLOCKED [careful mode]: TRUNCATE statement. Deactivate with /my-careful if intentional."}'
  exit 2
fi
if echo "$CMD_LOWER" | grep -qE 'delete\s+from\s+' && ! echo "$CMD_LOWER" | grep -qiE 'where\s'; then
  echo '{"error": "BLOCKED [careful mode]: DELETE FROM without WHERE clause. Deactivate with /my-careful if intentional."}'
  exit 2
fi

# --- Docker destructive operations ---
if echo "$CMD_LOWER" | grep -qE 'docker\s+system\s+prune'; then
  echo '{"error": "BLOCKED [careful mode]: docker system prune removes all unused data. Deactivate with /my-careful if intentional."}'
  exit 2
fi

# --- System destructive operations ---
if echo "$CMD_LOWER" | grep -qE 'kill\s+-9'; then
  echo '{"error": "BLOCKED [careful mode]: kill -9 ungraceful termination. Use kill (SIGTERM) first. Deactivate with /my-careful if intentional."}'
  exit 2
fi
if echo "$CMD_LOWER" | grep -qE 'chmod\s+777'; then
  echo '{"error": "BLOCKED [careful mode]: chmod 777 sets insecure permissions. Deactivate with /my-careful if intentional."}'
  exit 2
fi
if echo "$CMD_LOWER" | grep -qE '(mkfs|dd\s+if=)'; then
  echo '{"error": "BLOCKED [careful mode]: disk-level destructive operation. Deactivate with /my-careful if intentional."}'
  exit 2
fi

exit 0
