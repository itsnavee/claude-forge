#!/bin/bash
# ============================================================================
# Hook: Re-read detector
# Event: PreToolUse (Read)
# Action: Count reads of the same (session, file_path); warn at >=3, never block
#
# The warning is advisory. The model may legitimately re-read a file after
# editing it. The goal is just to surface a signal so repetitive re-reads
# become visible in the output and can be caught.
# ============================================================================

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[ -z "$SESSION_ID" ] && exit 0
[ -z "$FILE_PATH" ] && exit 0

CACHE_DIR="$HOME/.claude/cache"
COUNT_FILE="$CACHE_DIR/read-counts-${SESSION_ID}.txt"
mkdir -p "$CACHE_DIR" || exit 0

# Count existing reads of this exact file in this session
CURRENT=$(grep -cFx "$FILE_PATH" "$COUNT_FILE" 2>/dev/null || echo 0)
echo "$FILE_PATH" >> "$COUNT_FILE"
NEW=$((CURRENT + 1))

if [ "$NEW" -ge 3 ]; then
  echo "⚠ re-read: $FILE_PATH (${NEW}x this session). Use offset/limit or cache the result." >&2
fi

exit 0
