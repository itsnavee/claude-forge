#!/bin/bash
# ============================================================================
# Hook: Append-only event log
# Event: All hooks call this to log structured events
# Output: ~/.claude/events.jsonl
# Profile: standard,strict
# ============================================================================

# This is a LIBRARY, not a standalone hook.
# Source it from other hooks: source ~/.claude/hooks/events-logger.sh
# Then call: log_event "hook-name" "event-type" '{"key":"value"}'

EVENTS_FILE="$HOME/.claude/events.jsonl"

log_event() {
  local hook="$1"
  local event="$2"
  local data="${3:-{}}"
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local session="${CLAUDE_SESSION_ID:-unknown}"

  echo "{\"ts\":\"$ts\",\"hook\":\"$hook\",\"event\":\"$event\",\"session\":\"${session:0:8}\",\"data\":$data}" >> "$EVENTS_FILE"

  # Rotate if > 10MB
  if [ -f "$EVENTS_FILE" ]; then
    local size
    size=$(stat -f%z "$EVENTS_FILE" 2>/dev/null || stat -c%s "$EVENTS_FILE" 2>/dev/null || echo 0)
    if [ "$size" -gt 10485760 ]; then
      mv "$EVENTS_FILE" "${EVENTS_FILE}.$(date +%Y%m%d)"
    fi
  fi
}
