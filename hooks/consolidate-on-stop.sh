#!/bin/bash
# ============================================================================
# Hook: Consolidate project dir on Stop
# Event: Stop
# Action: If the current session ran from inside a subdir of a git repo (or
# from a non-canonical /data/ path), move its transcripts/memory into the
# canonical project dir (~/code/github/<repo>) and delete the duplicate.
#
# This prevents the claude-projects/ tree from accumulating subdir-based
# project dirs every time claude is launched from inside a repo subfolder.
#
# The actual consolidation logic lives in scripts/consolidate-project-dirs.sh
# — this hook just invokes it in single-dir mode with the current cwd.
#
# Only runs on the standard profile (disable via ECC_DISABLED_HOOKS).
# ============================================================================

source ~/.claude/hooks/hook-gate.sh 2>/dev/null
hook_gate "stop:consolidate-projects" "standard,strict" 2>/dev/null || true

SCRIPT=~/.claude/scripts/consolidate-project-dirs.sh
[ ! -x "$SCRIPT" ] && exit 0

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$CWD" ] && CWD="$PWD"

# Only run if cwd is inside a git repo
REPO_ROOT=$(cd "$CWD" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)
[ -z "$REPO_ROOT" ] && exit 0

# Skip if cwd IS the repo root AND already under the canonical path
if [ "$CWD" = "$REPO_ROOT" ] && [[ "$CWD" == "$HOME/code/github/"* ]]; then
  exit 0
fi

# Let the consolidation script decide what to do for this specific cwd.
# It has its own LIVE_SECONDS guard, but we set it to 0 here because the
# session is ending and the Stop hook fires after the writer has flushed.
LIVE_SECONDS=0 "$SCRIPT" "$CWD" >> "$HOME/.claude/cache/consolidate-on-stop.log" 2>&1 &

exit 0
