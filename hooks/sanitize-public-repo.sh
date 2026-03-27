#!/bin/bash
# ============================================================================
# Hook: Sanitize check before pushing to public repos
# Event: PreToolUse (matcher: Bash)
# Action: Scans unpushed commits for sensitive patterns on public repos
# Profile: standard,strict
# ============================================================================

source ~/.claude/hooks/hook-gate.sh
hook_gate "pre:bash:sanitize-public" "standard,strict"

INPUT=$(cat)

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$COMMAND" ]] && exit 0

# Only check git push commands
if ! echo "$COMMAND" | grep -qE '^\s*(git\s+push|rtk\s+git\s+push)'; then
  exit 0
fi

# Check if we're in a public git repo
source ~/.claude/hooks/is-public-repo.sh
[[ -z "$REPO_ROOT" ]] && exit 0
[[ "$IS_PUBLIC_REPO" != "yes" ]] && exit 0

REPO_NAME=$(basename "$REPO_ROOT")
PATTERNS_FILE="$HOME/.claude/sanitize-patterns.conf"
[[ ! -f "$PATTERNS_FILE" ]] && exit 0

# Get unpushed commits diff
REMOTE_BRANCH=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)
if [[ -n "$REMOTE_BRANCH" ]]; then
  DIFF=$(git diff "$REMOTE_BRANCH"..HEAD 2>/dev/null)
else
  DIFF=$(git diff HEAD~10..HEAD 2>/dev/null || git diff HEAD 2>/dev/null)
fi

[[ -z "$DIFF" ]] && exit 0

# Check for suspicious dotfiles/dotfolders (allowlist approach)
# Only these dotfiles/dotfolders are safe in public repos
SAFE_DOTFILES='\.gitignore$|\.gitattributes$|\.gitkeep$|\.github/|\.editorconfig$|\.prettierrc|\.eslintrc|\.stylelintrc|\.dockerignore$|\.nvmrc$|\.node-version$|\.python-version$|\.tool-versions$|\.flake8$|\.pylintrc$|\.rubocop|\.husky/|\.changeset/|\.storybook/'
CHANGED_FILES=$(echo "$DIFF" | grep '^+++ b/' | sed 's|^+++ b/||')
SUSPECT_DOTFILES=$(echo "$CHANGED_FILES" | grep -E '(^|/)\.' | grep -Ev "$SAFE_DOTFILES" 2>/dev/null | head -5)
if [[ -n "$SUSPECT_DOTFILES" ]]; then
  VIOLATIONS="  Suspicious dotfiles (not in allowlist):\n$(echo "$SUSPECT_DOTFILES" | sed 's/^/    /')\n"
fi

# Read patterns (skip comments, blank lines, and @directives)
VIOLATIONS=""
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  [[ "$line" == \#* ]] && continue
  [[ "$line" == @* ]] && continue

  MATCHES=$(echo "$DIFF" | grep '^+' | grep -i "$line" 2>/dev/null | head -3)
  if [[ -n "$MATCHES" ]]; then
    VIOLATIONS="${VIOLATIONS}\n  Pattern: $line\n  Found in:\n$(echo "$MATCHES" | head -3 | sed 's/^/    /')\n"
  fi
done < "$PATTERNS_FILE"

if [[ -n "$VIOLATIONS" ]]; then
  echo "{\"error\": \"BLOCKED: Sensitive patterns detected in unpushed commits to PUBLIC repo '$REPO_NAME'. Run /my-sanitize to review and fix.\n\nViolations:${VIOLATIONS}\"}"
  exit 2
fi

exit 0
