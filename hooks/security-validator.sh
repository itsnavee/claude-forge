#!/bin/bash
# ============================================================================
# Hook: Security validator — warns on risky operations
# Event: PreToolUse (matcher: Bash)
# Mode: WARNING only (log, don't block) — tighten to blocking after 2 weeks
# Profile: standard,strict
# ============================================================================

source ~/.claude/hooks/hook-gate.sh
hook_gate "pre:bash:security-validator" "standard,strict"

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$COMMAND" ]] && exit 0

# Source events logger
source ~/.claude/hooks/events-logger.sh

CMD_LOWER=$(echo "$COMMAND" | tr '[:upper:]' '[:lower:]' | tr -s ' ')

# --- .env file access ---
if echo "$CMD_LOWER" | grep -qE 'cat\s+.*\.env($|\s)|head\s+.*\.env($|\s)|less\s+.*\.env($|\s)'; then
  log_event "security-validator" "warn" "{\"pattern\":\"env-file-read\",\"cmd\":\"$(echo "$COMMAND" | head -c 100)\"}"
  # WARNING mode — log but don't block
  exit 0
fi

# --- File deletion outside project ---
if echo "$CMD_LOWER" | grep -qE 'rm\s+-[a-z]*r' && ! echo "$COMMAND" | grep -q "$(pwd)"; then
  log_event "security-validator" "warn" "{\"pattern\":\"rm-outside-project\",\"cmd\":\"$(echo "$COMMAND" | head -c 100)\"}"
  exit 0
fi

# --- curl to internal IPs ---
if echo "$CMD_LOWER" | grep -qE 'curl\s+.*\b(127\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.)'; then
  log_event "security-validator" "warn" "{\"pattern\":\"internal-ip-access\",\"cmd\":\"$(echo "$COMMAND" | head -c 100)\"}"
  exit 0
fi

# --- Package install without pin ---
if echo "$CMD_LOWER" | grep -qE '(npm install|pip install|gem install)\s+[a-z]' && ! echo "$CMD_LOWER" | grep -qE '@|==|>='; then
  log_event "security-validator" "warn" "{\"pattern\":\"unpinned-install\",\"cmd\":\"$(echo "$COMMAND" | head -c 100)\"}"
  exit 0
fi

exit 0
