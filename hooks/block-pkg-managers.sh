#!/bin/bash
# ============================================================================
# Hook: Block npm/yarn/pnpm/npx CLI commands
# Event: PreToolUse (Bash)
# Action: Exit 2 (blocks command, user can override)
#
# Enforces bun as the package manager for hot installs.
# Exemptions: firecrawl paths (uses pnpm legitimately)
# ============================================================================

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

[ -z "$COMMAND" ] && exit 0

# Exempt firecrawl paths
if echo "$COMMAND" | grep -qE '(firecrawl|/firecrawl)'; then
  exit 0
fi

if echo "$COMMAND" | grep -qE '\b(npm|yarn|pnpm|npx)\b'; then
  cat <<'MSG' >&2
Blocked: npm/yarn/pnpm/npx not allowed.
- For hot install in running container: use `bun add <pkg>`
- For permanent deps: update the app's package.json, deps install on container rebuild
MSG
  exit 2
fi

exit 0
