#!/bin/bash
# ============================================================================
# Hook: Enforce file size limit
# Event: PostToolUse (Edit, Write)
# Action: Exit 2 (feedback to Claude after file is already written)
# ============================================================================

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[ -z "$FILE_PATH" ] && exit 0
[ ! -f "$FILE_PATH" ] && exit 0

LINE_COUNT=$(wc -l < "$FILE_PATH" | tr -d ' ')

case "$FILE_PATH" in
  *.py)  MAX_LINES=1000 ;;
  *)     MAX_LINES=500 ;;
esac

if [ "$LINE_COUNT" -gt "$MAX_LINES" ]; then
  echo "FILE TOO LONG: $FILE_PATH is $LINE_COUNT lines (max $MAX_LINES). Per project rules, refactor into smaller modules." >&2
  exit 2
fi

exit 0
