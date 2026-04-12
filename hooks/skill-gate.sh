#!/bin/bash
# ============================================================================
# Hook: Skill cooldown gate — blocks re-invocation of expensive skills
# Event: PreToolUse (matcher: Skill)
# Profile: standard,strict
# Log: ~/.claude/skill-gate-log.tsv (append-only, tab-separated)
# ============================================================================

source ~/.claude/hooks/hook-gate.sh
hook_gate "pre:skill:gate" "standard,strict"

INPUT=$(cat)

# Extract skill name from tool input
SKILL=$(echo "$INPUT" | jq -r '.tool_input.skill // empty' 2>/dev/null)
[[ -z "$SKILL" ]] && exit 0

# ClaudeForge announce: print the skill being used so the model and user
# both see it without relying on the model remembering to say it.
# Goes to stderr so Claude Code surfaces it alongside tool output.
ARGS=$(echo "$INPUT" | jq -r '.tool_input.args // empty' 2>/dev/null | head -c 80)
echo "⚡ ClaudeForge: Using /${SKILL}${ARGS:+ — $ARGS}" >&2

# Cooldown map: skill_name -> seconds
# Update these when skill frontmatter changes
declare -A COOLDOWNS=(
  ["my-security-scan"]=1200       # 20m
  ["my-adversarial-review"]=1500  # 25m
  ["my-pr-review"]=600            # 10m
  ["my-code-gaps-fix"]=1200       # 20m
  ["my-generate-tests"]=600       # 10m
  ["my-qa"]=600                   # 10m
  ["my-research-targets"]=1200    # 20m
  ["bug-hunt"]=900                # 15m
)

# Not a gated skill — pass through
COOLDOWN=${COOLDOWNS[$SKILL]:-0}
[[ "$COOLDOWN" -eq 0 ]] && exit 0

LOG_FILE="$HOME/.claude/skill-gate-log.tsv"
[[ ! -f "$LOG_FILE" ]] && exit 0

# Find last run of this skill (read file once, grep for skill)
LAST_RUN=$(grep -E "^[0-9]+	${SKILL}$" "$LOG_FILE" | tail -1 | cut -f1)
[[ -z "$LAST_RUN" ]] && exit 0

NOW=$(date +%s)
ELAPSED=$(( NOW - LAST_RUN ))

if [[ "$ELAPSED" -lt "$COOLDOWN" ]]; then
  REMAINING=$(( (COOLDOWN - ELAPSED) / 60 ))
  REMAINING_SEC=$(( (COOLDOWN - ELAPSED) % 60 ))
  MINS_AGO=$(( ELAPSED / 60 ))

  # Format remaining time
  if [[ "$REMAINING" -gt 0 ]]; then
    WAIT="${REMAINING}m ${REMAINING_SEC}s"
  else
    WAIT="${REMAINING_SEC}s"
  fi

  echo "{\"error\": \"COOLDOWN: /${SKILL} last ran ${MINS_AGO}m ago (cooldown: $(( COOLDOWN / 60 ))m). Wait ${WAIT} or re-run with --force argument to bypass. This prevents wasting tokens on unchanged code.\"}"
  exit 2
fi

exit 0
