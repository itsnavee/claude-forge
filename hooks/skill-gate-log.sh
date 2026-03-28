#!/bin/bash
# ============================================================================
# Hook: Skill cooldown logger — records completion of gated skills
# Event: PostToolUse (matcher: Skill)
# Profile: standard,strict
# Log: ~/.claude/skill-gate-log.tsv (append-only, tab-separated)
# ============================================================================

source ~/.claude/hooks/hook-gate.sh
hook_gate "post:skill:gate-log" "standard,strict"

INPUT=$(cat)

# Extract skill name from tool input
SKILL=$(echo "$INPUT" | jq -r '.tool_input.skill // empty' 2>/dev/null)
[[ -z "$SKILL" ]] && exit 0

# Only log gated skills (same list as skill-gate.sh)
case "$SKILL" in
  my-security-scan|my-adversarial-review|my-pr-review|my-code-gaps-fix|\
  my-generate-tests|my-qa|my-research-targets|bug-hunt)
    ;;
  *)
    exit 0
    ;;
esac

LOG_FILE="$HOME/.claude/skill-gate-log.tsv"
NOW=$(date +%s)

# Append timestamp and skill name (atomic-ish via echo >> append)
echo -e "${NOW}\t${SKILL}" >> "$LOG_FILE"

# Prune: keep only last 200 lines to prevent unbounded growth
if [[ $(wc -l < "$LOG_FILE" 2>/dev/null) -gt 200 ]]; then
  tail -100 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
fi

exit 0
