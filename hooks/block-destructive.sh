#!/bin/bash
# ============================================================================
# Hook: Block destructive commands
# Event: PreToolUse (Bash)
# Action: Exit 2 (blocks command, user can override)
# ============================================================================

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

[ -z "$COMMAND" ] && exit 0

BLOCKED_PATTERNS=(
  'rm\s+-rf'
  'rm\s+-fr'
  'git\s+push\s+.*--force'
  'git\s+push\s+.*-f\b'
  'git\s+reset\s+--hard'
  'git\s+clean\s+-f'
  'docker\s+system\s+prune'
)

for pattern in "${BLOCKED_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qE "$pattern"; then
    echo "DESTRUCTIVE COMMAND BLOCKED: matched '$pattern'. Override manually if this is intentional." >&2
    exit 2
  fi
done

exit 0
