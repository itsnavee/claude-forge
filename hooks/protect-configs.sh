#!/bin/bash
# ============================================================================
# Hook: Protect config and secrets files from AI edits
# Event: PreToolUse (Edit, Write)
# Action: Exit 2 (blocks edit, user can override)
# ============================================================================

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[ -z "$FILE_PATH" ] && exit 0

if echo "$FILE_PATH" | grep -qE '(configs/\.env|/\.env\.)'; then
  echo "PROTECTED FILE: $FILE_PATH — secrets/env files should not be edited by AI. Override manually if needed." >&2
  exit 2
fi

exit 0
