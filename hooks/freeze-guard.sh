#!/bin/bash
# ============================================================================
# Hook: Block edits outside frozen directory
# Event: PreToolUse (matcher: Edit, Write)
# Activated by: /freeze skill (creates /tmp/claude-freeze-dir.flag)
# Profile: standard,strict
# ============================================================================

source ~/.claude/hooks/hook-gate.sh
hook_gate "pre:edit:freeze-guard" "standard,strict"

# Skip if freeze mode is not active
[[ ! -f /tmp/claude-freeze-dir.flag ]] && exit 0

ALLOWED_DIR=$(cat /tmp/claude-freeze-dir.flag 2>/dev/null)
[[ -z "$ALLOWED_DIR" ]] && exit 0

INPUT=$(cat)

# Extract file_path from tool input (works for both Edit and Write tools)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[[ -z "$FILE_PATH" ]] && exit 0

# Check if file path starts with allowed directory
if [[ "$FILE_PATH" != "$ALLOWED_DIR"* ]]; then
  echo "{\"error\": \"BLOCKED [freeze mode]: Cannot edit $FILE_PATH — edits restricted to $ALLOWED_DIR. Run /my-freeze off to deactivate.\"}"
  exit 2
fi

exit 0
