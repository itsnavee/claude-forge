#!/bin/bash
# ============================================================================
# Hook: Auto-generate session summary on stop
# Event: Stop
# Action: Blocks first stop to request Claude append a session summary,
#         allows stop on re-entry (stop_hook_active=true)
# ============================================================================

source ~/.claude/hooks/hook-gate.sh
hook_gate "stop:session-summary" "standard,strict"

INPUT=$(cat)
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active')

if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

# Refuse to write a session summary when cwd is / or $HOME — writing would
# produce paths like //.claude/sessions/... or ~/.claude/sessions/... which
# pollute the global tree and obscure which project the session belongs to.
if [ "$PWD" = "$HOME" ] || [ "$PWD" = "/" ]; then
  echo "session-summary: refusing to write from cwd=$PWD (no project context)" >&2
  exit 0
fi

# Skip for claude-config repo (config repo, not a project)
REPO_NAME=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)
if [ "$REPO_NAME" = "claude-config" ]; then
  exit 0
fi

# Skip for public repos (session summaries can contain sensitive context)
source ~/.claude/hooks/is-public-repo.sh
if [ "$IS_PUBLIC_REPO" = "yes" ]; then
  exit 0
fi

# CWD is project root; git fallback as safety net
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')
SHORT_ID=$(echo "$SESSION_ID" | cut -c1-8)
TODAY=$(date +%Y-%m-%d)

# Ensure .claude dirs exist
mkdir -p "$PROJECT_ROOT/.claude/sessions"
mkdir -p "$PROJECT_ROOT/.claude/transcripts"

TARGET_FILE="$PROJECT_ROOT/.claude/sessions/summary_${TODAY}.md"

# Check if this session already wrote to today's file — if so, skip everything
# (avoids re-copying transcript and leaving untracked files after a git push)
if [ -f "$TARGET_FILE" ] && grep -q "Session: ${SHORT_ID}" "$TARGET_FILE"; then
  exit 0
fi

# Copy session transcript JSONL to project
TRANSCRIPT=$(find "$HOME/.claude/projects" -name "${SESSION_ID}.jsonl" -type f 2>/dev/null | head -1)
if [ -n "$TRANSCRIPT" ]; then
  cp "$TRANSCRIPT" "$PROJECT_ROOT/.claude/transcripts/"
fi

# Determine if appending or creating
if [ -f "$TARGET_FILE" ]; then
  INSTRUCTION="Append a session summary to ${TARGET_FILE} (file already exists — add a --- separator then your summary)."
else
  INSTRUCTION="Write a session summary to ${TARGET_FILE}."
fi

cat <<EOF
{
  "decision": "block",
  "reason": "${INSTRUCTION} Start with:\n\n---\n\n## Session: ${SHORT_ID}\n### Task: <brief task title>\n\n<1-2 sentence overview>\n\n### Changes Made\n- \`path/to/file\` — what changed\n\n### Status\nComplete/Incomplete. Any follow-up notes.\n\nKeep it concise. Skip sections that don't apply."
}
EOF
exit 0
