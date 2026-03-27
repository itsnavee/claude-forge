#!/bin/bash
# ============================================================================
# Hook: Block git add of build artifacts
# Event: PreToolUse (matcher: Bash)
# Action: Rejects git add commands that include banned paths
# Profile: standard,strict
# ============================================================================

source ~/.claude/hooks/hook-gate.sh
hook_gate "pre:bash:git-add-guard" "standard,strict"

INPUT=$(cat)

# Only check Bash tool calls
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$COMMAND" ]] && exit 0

# Only check git add commands
if ! echo "$COMMAND" | grep -qE '^\s*git\s+add'; then
  exit 0
fi

# Blocked patterns
BLOCKED_PATTERNS=(
  "node_modules"
  ".next"
  ".nuxt"
  ".turbo"
  ".wrangler"
  ".parcel-cache"
  ".svelte-kit"
  ".expo"
  ".vercel"
  ".netlify"
  "__pycache__"
  "dist/"
  "vendor/"
)

# Check for "git add ." or "git add -A" (broad adds that could catch artifacts)
if echo "$COMMAND" | grep -qE 'git\s+add\s+(-A|\.\s*$|\.\s+)'; then
  echo '{"error": "BLOCKED: Use specific file paths with git add instead of broad patterns (git add . or git add -A). This prevents accidentally staging node_modules, dist, or other build artifacts."}'
  exit 2
fi

# Check for explicit banned paths
for pattern in "${BLOCKED_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qi "$pattern"; then
    echo "{\"error\": \"BLOCKED: Cannot git add path matching '$pattern'. These are build artifacts that belong in .gitignore, not in git.\"}"
    exit 2
  fi
done

exit 0
