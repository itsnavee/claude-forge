#!/bin/bash
# ============================================================================
# Hook Gating Library
# Source this file, then call: hook_gate "<hook-id>" "<profiles>"
#
# Env vars:
#   ECC_HOOK_PROFILE    - minimal|standard|strict (default: standard)
#   ECC_DISABLED_HOOKS  - comma-separated hook IDs to skip
#
# Example:
#   source ~/.claude/hooks/hook-gate.sh
#   hook_gate "stop:session-summary" "standard,strict"
# ============================================================================

hook_gate() {
  local hook_id="$1"
  local profiles="${2:-minimal,standard,strict}"

  # Check if hook is explicitly disabled
  if [[ -n "$ECC_DISABLED_HOOKS" ]]; then
    IFS=',' read -ra DISABLED <<< "$ECC_DISABLED_HOOKS"
    for d in "${DISABLED[@]}"; do
      [[ "$d" == "$hook_id" ]] && exit 0
    done
  fi

  # Check if current profile allows this hook
  local current="${ECC_HOOK_PROFILE:-standard}"
  if [[ ! ",$profiles," == *",$current,"* ]]; then
    exit 0
  fi
}
