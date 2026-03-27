#!/usr/bin/env bash
# Hook: timestamp
# Rule: Show DD/MM HH:MM:SS timestamp at hook events
# Created: 2026-03-13

source ~/.claude/hooks/hook-gate.sh 2>/dev/null
hook_gate "timestamp" "minimal,standard,strict" 2>/dev/null

echo "$(date '+%d/%m %H:%M:%S')"
exit 0
