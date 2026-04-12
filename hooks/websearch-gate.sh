#!/bin/bash
# ============================================================================
# Hook: WebSearch query gate
# Event: PreToolUse (matcher: WebSearch)
# Action: Warn on overly-broad queries. Don't block — just nudge.
#
# Since Claude Code hooks can't cap PostToolUse result size, the only
# effective lever is to prevent broad queries in the first place. A broad
# query returns dozens of hits and fills context. Narrow queries return few.
# ============================================================================

INPUT=$(cat)
QUERY=$(echo "$INPUT" | jq -r '.tool_input.query // empty')

[ -z "$QUERY" ] && exit 0

# Count terms (whitespace-separated). <3 terms = broad.
TERM_COUNT=$(echo "$QUERY" | wc -w | tr -d ' ')

if [ "$TERM_COUNT" -lt 3 ]; then
  echo "⚠ WebSearch query \"$QUERY\" has only ${TERM_COUNT} term(s) — likely to return >50 broad hits. Consider adding more specific terms, a site: filter, or a year to narrow. Not blocking." >&2
fi

exit 0
