#!/bin/bash
# ============================================================================
# Hook: Block raw `git commit` when /my-git-sync skill exists
# Event: PreToolUse (Bash)
# Action: Nudge toward /my-git-sync. Bypass with COMMIT_BYPASS=1.
#
# Rationale: /my-git-sync adds the Co-Authored-By trailer, handles rebase,
# and runs sanitization. Raw `git commit` skips all of that.
# ============================================================================

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

[ -z "$COMMAND" ] && exit 0

# Only block when /my-git-sync is actually installed
[ ! -f "$HOME/.claude/skills/my-git-sync/SKILL.md" ] && exit 0

# Allow if bypass flag present in the command itself
if echo "$COMMAND" | grep -qE 'COMMIT_BYPASS=1'; then
  exit 0
fi

# Match `git commit` as a command (not inside a string or path).
# Require `git commit` at start-of-command or after a shell separator.
if echo "$COMMAND" | grep -qE '(^|[;&|(]|&&|\|\|)[[:space:]]*git[[:space:]]+commit\b'; then
  echo "blocked: use /my-git-sync instead of raw \`git commit\` — adds co-author trailer, handles rebase, runs sanitization." >&2
  echo "override: prefix the command with COMMIT_BYPASS=1 if the /my-git-sync workflow is genuinely wrong for this commit." >&2
  exit 2
fi

exit 0
