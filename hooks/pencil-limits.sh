#!/bin/bash
# ============================================================================
# Hook: Pencil MCP usage limits
# Event: PreToolUse (matchers: mcp__pencil__get_screenshot,
#                              mcp__pencil__get_variables)
# Action:
#   - get_variables: BLOCK (pencil MCP nags when this is called)
#   - get_screenshot: rate-limit to 5 per session, then require bypass
#
# These are gates at the SOURCE — Claude Code hooks can't rewrite tool_result
# content, so we prevent the expensive call from happening in the first place.
# Override with PENCIL_BYPASS=1 in the environment.
# ============================================================================

[ -n "$PENCIL_BYPASS" ] && exit 0

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

[ -z "$TOOL" ] && exit 0
[ -z "$SESSION_ID" ] && exit 0

# get_variables is pure nag-producer — pencil MCP responds with
# "calling get_variables is not necessary anymore" plus a variable dump.
# Best mitigation: prevent the call entirely.
if [ "$TOOL" = "mcp__pencil__get_variables" ]; then
  echo "blocked: mcp__pencil__get_variables is a deprecated call that pencil MCP nags about. Use get_editor_state or batch_get instead. Override: PENCIL_BYPASS=1" >&2
  exit 2
fi

# Rate-limit get_screenshot to avoid 1 MB tool_results filling context.
if [ "$TOOL" = "mcp__pencil__get_screenshot" ]; then
  CACHE_DIR="$HOME/.claude/cache"
  mkdir -p "$CACHE_DIR" || exit 0
  COUNT_FILE="$CACHE_DIR/pencil-screenshots-${SESSION_ID}.txt"

  CURRENT=$(cat "$COUNT_FILE" 2>/dev/null || echo 0)
  NEW=$((CURRENT + 1))
  CAP=${PENCIL_SCREENSHOT_CAP:-5}

  if [ "$NEW" -gt "$CAP" ]; then
    echo "blocked: ${CAP} screenshots already taken this session (each ~200KB). If you really need more, use export_nodes for specific regions, or set PENCIL_BYPASS=1." >&2
    exit 2
  fi

  printf '%d\n' "$NEW" > "$COUNT_FILE"
fi

exit 0
