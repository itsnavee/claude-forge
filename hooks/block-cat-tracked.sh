#!/bin/bash
# ============================================================================
# Hook: Block cat/head/tail/less/more on tracked-extension files
# Event: PreToolUse (Bash)
# Action: Block with guidance to use the Read tool instead. Does not block
# piped forms (cat file | jq ...) — those are legitimate stream processing.
# ============================================================================

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

[ -z "$COMMAND" ] && exit 0

# Only match when cat/head/tail/less/more is used standalone (no pipe after)
# against a tracked-extension file. Structure:
#   (start or ; or &&) <viewer> <flags?> <file.ext>
# We allow piped forms by requiring the line to END with the file (or
# the viewer to not be followed by a pipe).
#
# Strategy: strip anything after the first unquoted | ; && or end.
# Test whether the remaining command matches: viewer + file.ext + EOL.
VIEWERS='(cat|head|tail|less|more)'
EXTENSIONS='(md|ts|tsx|js|jsx|py|go|rs|json|ya?ml|toml|sh|txt|html|css|scss)'

# Allow piped/chained forms — `cat file | jq`, `cat file; other` are
# legitimate stream processing, not a naive "read this file" pattern.
if echo "$COMMAND" | grep -qE '[|;&]'; then
  exit 0
fi

# Pure viewer on a tracked-extension file? Block.
# Pattern: viewer + whitespace + anything + <filename>.<ext> at end-of-command.
if echo "$COMMAND" | grep -qE "^[[:space:]]*${VIEWERS}[[:space:]].*[^[:space:]]+\\.${EXTENSIONS}[[:space:]]*$"; then
  echo "blocked: do not use cat/head/tail/less/more on source files — use the Read tool instead (offset/limit, cached, structured)." >&2
  echo "command was: $COMMAND" >&2
  exit 2
fi

exit 0
