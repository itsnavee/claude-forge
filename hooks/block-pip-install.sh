#!/bin/bash
# ============================================================================
# Hook: Block direct pip install commands
# Event: PreToolUse (Bash)
# Action: Exit 2 (blocks command, user can override)
# ============================================================================

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

[ -z "$COMMAND" ] && exit 0

if echo "$COMMAND" | grep -qE '\bpip3?\s+install\b'; then
  cat <<'MSG' >&2
Blocked: pip install not allowed directly.
Update requirements.txt instead — deps install on container rebuild.
MSG
  exit 2
fi

exit 0
