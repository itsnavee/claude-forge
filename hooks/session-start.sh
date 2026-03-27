#!/bin/bash
# ============================================================================
# Hook: Session startup (lightweight)
# Event: SessionStart (Notification)
# Action: Reports available session history without injecting it
# Profile: minimal,standard,strict
# ============================================================================

source ~/.claude/hooks/hook-gate.sh
hook_gate "start:session-loader" "minimal,standard,strict"
source ~/.claude/hooks/events-logger.sh
log_event "session-start" "start" "{\"cwd\":\"$(pwd)\"}"

# Find project root
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

# Skip if home directory
[[ "$PROJECT_ROOT" == "$HOME" ]] && exit 0

SESSION_DIR="$PROJECT_ROOT/.claude/sessions"
[[ ! -d "$SESSION_DIR" ]] && exit 0

# Count recent sessions (last 3 days) — report availability, don't inject
COUNT=$(find "$SESSION_DIR" -name "summary_*.md" -mtime -3 -type f 2>/dev/null | wc -l | tr -d ' ')

if [[ "$COUNT" -gt 0 ]]; then
  LATEST=$(find "$SESSION_DIR" -name "summary_*.md" -mtime -3 -type f 2>/dev/null | sort -r | head -1)
  echo "${COUNT} recent session(s) available. Run /my-catchup to load context."
fi

exit 0
