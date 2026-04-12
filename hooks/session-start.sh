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

# Warn (but don't block) if launched from / or $HOME — hooks that write
# project files silently no-op in these locations, which is confusing.
if [[ "$PROJECT_ROOT" == "$HOME" ]] || [[ "$PROJECT_ROOT" == "/" ]]; then
  echo "⚠ claude started from $PROJECT_ROOT (no project context). Session hooks (summary, transcripts) will skip. cd into a project to enable them."
  exit 0
fi

# Path canonicalization warning. ~/code/github/* and ~/data/code/github/* are
# hardlinked to the same inodes, but the canonical form is ~/code/github/*
# (shorter, appears in most docs). Warn once when launched from the non-
# canonical variant so transcripts/memory keys stay consistent across machines.
if [[ "$PROJECT_ROOT" == "$HOME/data/code/github/"* ]]; then
  CANONICAL="${PROJECT_ROOT/#$HOME\/data\/code\/github\//$HOME/code/github/}"
  echo "⚠ launched from non-canonical path: $PROJECT_ROOT"
  echo "   canonical form: $CANONICAL"
  echo "   same data (hardlinked) but using the canonical form keeps session keys consistent."
fi

SESSION_DIR="$PROJECT_ROOT/.claude/sessions"
[[ ! -d "$SESSION_DIR" ]] && exit 0

# Count recent sessions (last 3 days) — report availability, don't inject
COUNT=$(find "$SESSION_DIR" -name "summary_*.md" -mtime -3 -type f 2>/dev/null | wc -l | tr -d ' ')

if [[ "$COUNT" -gt 0 ]]; then
  LATEST=$(find "$SESSION_DIR" -name "summary_*.md" -mtime -3 -type f 2>/dev/null | sort -r | head -1)
  echo "${COUNT} recent session(s) available. Run /my-catchup to load context."
fi

exit 0
