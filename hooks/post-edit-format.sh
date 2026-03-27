#!/bin/bash
# ============================================================================
# Hook: Auto-format after file edits
# Event: PostToolUse (Notification, matcher: Edit)
# Action: Detects Biome/Prettier in project and formats the edited file
# Profile: standard,strict
# ============================================================================

source ~/.claude/hooks/hook-gate.sh
hook_gate "post:edit:format" "standard,strict"

INPUT=$(cat)

# Get the file that was edited
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[[ -z "$FILE_PATH" ]] && exit 0

# Only format JS/TS files
case "$FILE_PATH" in
  *.ts|*.tsx|*.js|*.jsx|*.json|*.css|*.scss) ;;
  *) exit 0 ;;
esac

[[ ! -f "$FILE_PATH" ]] && exit 0

# Walk up to find project root with a formatter
DIR=$(dirname "$FILE_PATH")
FORMATTER=""
PKG_EXEC=""
PROJECT_DIR=""

while [[ "$DIR" != "/" && "$DIR" != "$HOME" ]]; do
  # Detect package manager
  if [[ -f "$DIR/bun.lockb" || -f "$DIR/bun.lock" ]]; then
    PKG_EXEC="bunx"
  elif [[ -f "$DIR/pnpm-lock.yaml" ]]; then
    PKG_EXEC="pnpm exec"
  elif [[ -f "$DIR/yarn.lock" ]]; then
    PKG_EXEC="yarn"
  elif [[ -f "$DIR/package-lock.json" ]]; then
    PKG_EXEC="npx"
  fi

  # Detect formatter
  if [[ -f "$DIR/biome.json" || -f "$DIR/biome.jsonc" ]]; then
    FORMATTER="biome"
    PROJECT_DIR="$DIR"
    break
  elif [[ -f "$DIR/.prettierrc" || -f "$DIR/.prettierrc.json" || -f "$DIR/.prettierrc.js" || \
          -f "$DIR/.prettierrc.cjs" || -f "$DIR/.prettierrc.yaml" || -f "$DIR/.prettierrc.yml" || \
          -f "$DIR/.prettierrc.toml" || -f "$DIR/prettier.config.js" || -f "$DIR/prettier.config.cjs" ]]; then
    FORMATTER="prettier"
    PROJECT_DIR="$DIR"
    break
  fi

  DIR=$(dirname "$DIR")
done

[[ -z "$FORMATTER" || -z "$PKG_EXEC" ]] && exit 0

# Run formatter (non-blocking, 15s timeout)
cd "$PROJECT_DIR" 2>/dev/null || exit 0

if [[ "$FORMATTER" == "biome" ]]; then
  timeout 15 $PKG_EXEC biome format --write "$FILE_PATH" >/dev/null 2>&1
elif [[ "$FORMATTER" == "prettier" ]]; then
  timeout 15 $PKG_EXEC prettier --write "$FILE_PATH" >/dev/null 2>&1
fi

exit 0
