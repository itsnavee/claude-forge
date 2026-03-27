#!/bin/bash
# ============================================================================
# Hook: Auto-resume after usage limit
# Event: Stop
# Action: Detects usage limit stop via JSONL transcript, sleeps until reset,
#         then injects a continue prompt via block decision.
#         Natural retry loop — no API keys needed.
# ============================================================================

source ~/.claude/hooks/hook-gate.sh
hook_gate "stop:usage-limit-resume" "minimal,standard,strict"

INPUT=$(cat)
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active')

# On re-entry after a block decision, allow stop
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')

# Find session JSONL transcript
TRANSCRIPT=$(find "$HOME/.claude/projects" -name "${SESSION_ID}.jsonl" -type f 2>/dev/null | head -1)

if [ -z "$TRANSCRIPT" ]; then
  exit 0
fi

# Check last 100 lines for usage limit event
# jq processes each JSONL line as a separate JSON value
RATE_LIMIT_LINE=$(tail -100 "$TRANSCRIPT" \
  | jq -c 'select(.type == "rate_limit_event") | select(
      .rate_limit_info.isUsingOverage == true or
      (.rate_limit_info.overageDisabledReason != null and .rate_limit_info.overageDisabledReason != "")
    )' 2>/dev/null \
  | tail -1)

if [ -z "$RATE_LIMIT_LINE" ]; then
  exit 0
fi

# Usage limit detected — compute sleep duration
NOW=$(date +%s)
RESET_AT=$(echo "$RATE_LIMIT_LINE" | jq -r '.rate_limit_info.resetAt // empty' 2>/dev/null)

if [ -n "$RESET_AT" ]; then
  # Sleep until the resetAt timestamp (Linux: date -d, macOS fallback: date -j)
  RESET_EPOCH=$(date -d "$RESET_AT" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "${RESET_AT}" +%s 2>/dev/null)
  if [ -n "$RESET_EPOCH" ] && [ "$RESET_EPOCH" -gt "$NOW" ]; then
    SLEEP_SECS=$((RESET_EPOCH - NOW + 30))
  else
    NEXT_HOUR=$(( (NOW / 3600 + 1) * 3600 ))
    SLEEP_SECS=$((NEXT_HOUR - NOW + 120))
  fi
else
  # No resetAt — sleep until next hour boundary + 120s safety margin
  NEXT_HOUR=$(( (NOW / 3600 + 1) * 3600 ))
  SLEEP_SECS=$((NEXT_HOUR - NOW + 120))
fi

# Minimum 60s to avoid tight spin loops
[ "$SLEEP_SECS" -lt 60 ] && SLEEP_SECS=120

sleep "$SLEEP_SECS"

printf '{"decision":"block","reason":"Usage limit has reset. Please continue with the task you were working on before hitting the limit."}\n'
exit 0
