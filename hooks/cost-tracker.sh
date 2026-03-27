#!/bin/bash
# ============================================================================
# Hook: Track token usage and estimated cost per session
# Event: Stop (Notification)
# Action: Appends token/cost data to ~/.claude/metrics/costs.jsonl
# Profile: standard,strict
# ============================================================================

source ~/.claude/hooks/hook-gate.sh
hook_gate "stop:cost-tracker" "standard,strict"
source ~/.claude/hooks/events-logger.sh

INPUT=$(cat)

# Extract token usage
INPUT_TOKENS=$(echo "$INPUT" | jq -r '.usage.input_tokens // .input_tokens // 0' 2>/dev/null)
OUTPUT_TOKENS=$(echo "$INPUT" | jq -r '.usage.output_tokens // .output_tokens // 0' 2>/dev/null)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)
MODEL=$(echo "$INPUT" | jq -r '.model // "unknown"' 2>/dev/null)

# Skip if no meaningful usage
[[ "$INPUT_TOKENS" == "0" && "$OUTPUT_TOKENS" == "0" ]] && exit 0
[[ "$INPUT_TOKENS" == "null" ]] && INPUT_TOKENS=0
[[ "$OUTPUT_TOKENS" == "null" ]] && OUTPUT_TOKENS=0

# Cost rates per 1M tokens (input/output)
# Haiku: $0.80/$4.00, Sonnet: $3/$15, Opus: $15/$75
if echo "$MODEL" | grep -qi "haiku"; then
  INPUT_RATE="0.80"
  OUTPUT_RATE="4.00"
elif echo "$MODEL" | grep -qi "opus"; then
  INPUT_RATE="15.00"
  OUTPUT_RATE="75.00"
else
  # Default to Sonnet rates
  INPUT_RATE="3.00"
  OUTPUT_RATE="15.00"
fi

# Calculate estimated cost (using awk for float math)
COST=$(awk "BEGIN { printf \"%.6f\", ($INPUT_TOKENS * $INPUT_RATE / 1000000) + ($OUTPUT_TOKENS * $OUTPUT_RATE / 1000000) }")

# Write metrics
METRICS_DIR="$HOME/.claude/metrics"
mkdir -p "$METRICS_DIR"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "{\"ts\":\"$TIMESTAMP\",\"session\":\"$SESSION_ID\",\"model\":\"$MODEL\",\"in\":$INPUT_TOKENS,\"out\":$OUTPUT_TOKENS,\"cost_usd\":$COST}" \
  >> "$METRICS_DIR/costs.jsonl"

log_event "cost-tracker" "session-cost" "{\"model\":\"$MODEL\",\"in\":$INPUT_TOKENS,\"out\":$OUTPUT_TOKENS,\"cost_usd\":$COST}"

exit 0
