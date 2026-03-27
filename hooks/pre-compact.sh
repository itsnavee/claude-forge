#!/bin/bash
# ============================================================================
# Hook: Save working state before context compaction
# Event: PreCompact (Notification)
# Action: Logs compaction event and saves current state markers
# Profile: minimal,standard,strict
# ============================================================================

source ~/.claude/hooks/hook-gate.sh
hook_gate "compact:pre-save" "minimal,standard,strict"

INPUT=$(cat)

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
[[ "$PROJECT_ROOT" == "$HOME" ]] && exit 0

SESSION_DIR="$PROJECT_ROOT/.claude/sessions"
mkdir -p "$SESSION_DIR"

COMPACT_LOG="$SESSION_DIR/compaction-log.txt"
TODAY=$(date +%Y-%m-%d)
NOW=$(date "+%Y-%m-%d %H:%M:%S")
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)

# Log compaction event
echo "[$NOW] Compaction triggered | session=$SESSION_ID | dir=$PWD" >> "$COMPACT_LOG"

# Snapshot active state from state.md so it survives compaction
STATE_FILE="$PROJECT_ROOT/state.md"
if [[ -f "$STATE_FILE" ]]; then
  echo "--- state snapshot at $NOW ---" >> "$COMPACT_LOG"
  # Extract Active Decisions and Resume Point sections
  sed -n '/^## Active Decisions/,/^## /{ /^## Active Decisions/p; /^## [^A]/!p; }' "$STATE_FILE" >> "$COMPACT_LOG"
  sed -n '/^## Resume Point/,/^## /{ /^## Resume Point/p; /^## [^R]/!p; }' "$STATE_FILE" >> "$COMPACT_LOG"
  echo "--- end snapshot ---" >> "$COMPACT_LOG"
fi

# Append compaction marker to today's session summary if it exists
SUMMARY_FILE="$SESSION_DIR/summary_${TODAY}.md"
if [[ -f "$SUMMARY_FILE" ]]; then
  echo "" >> "$SUMMARY_FILE"
  echo "> **Context compacted at $NOW** — review above for prior context." >> "$SUMMARY_FILE"
fi

exit 0
