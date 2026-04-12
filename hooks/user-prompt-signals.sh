#!/bin/bash
# ============================================================================
# Hook: UserPromptSubmit signals
# Event: UserPromptSubmit
#
# Combined hook that handles three plan items:
#   3.5 skill-name preprocessor — if the user types /<skill-name> mid-sentence,
#       inject a hint so the model routes it.
#   4.3 migration-runbook detector — tracks "architecture question" patterns
#       and nudges toward docs/runbook-<subsystem>.md after 3 hits.
#   3.4 narration-rewriter telemetry — scans the prior assistant text in the
#       transcript for narration patterns ("Let me X") and bumps a counter.
#
# Output goes to STDERR so it surfaces as additional context to the model.
# Exit 0 always — never block user input.
# ============================================================================

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // .user_message // empty' 2>/dev/null)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)

[ -z "$PROMPT" ] && exit 0
[ -z "$SESSION_ID" ] && exit 0

CACHE_DIR="$HOME/.claude/cache"
mkdir -p "$CACHE_DIR" || exit 0

# ----------------------------------------------------------------------------
# 3.5 — Skill-name preprocessor
# Scan the prompt for `/<installed-skill-name>\b`. If found AND the message is
# NOT already a slash-command on its own line, emit a hint.
# ----------------------------------------------------------------------------
SKILLS_DIR="$HOME/.claude/skills"
if [ -d "$SKILLS_DIR" ]; then
  # Only trigger if the prompt isn't itself a bare slash command like "/my-foo args"
  if ! echo "$PROMPT" | head -1 | grep -qE '^\s*/[a-z]'; then
    # Find /<skill-name> occurrences. Use word-boundary so /foo/bar paths don't match.
    MATCHED=$(echo "$PROMPT" | grep -oE '/[a-zA-Z][a-zA-Z0-9_-]+' | sort -u)
    for token in $MATCHED; do
      name=${token#/}
      if [ -d "$SKILLS_DIR/$name" ]; then
        echo "💡 detected skill reference: $token — invoke via the Skill tool (name=$name)" >&2
      fi
    done
  fi
fi

# ----------------------------------------------------------------------------
# 4.3 — Migration-runbook detector
# Track "architecture question" heuristic: prompts matching `how would we`,
# `is X still`, `what if we`, `should we migrate`, `why is our`, etc.
# Per-session counter keyed by keyword. At 3 hits on the same keyword, nudge.
# ----------------------------------------------------------------------------
ARCH_RE='(how would we|is [a-z]+ still|what if we|should we migrate|why is our|can we still|are we using|does it still|how do we)'
if echo "$PROMPT" | grep -qiE "$ARCH_RE"; then
  # Extract a subject keyword — pick the longest alphabetic word in the prompt
  # that isn't a common stopword. Good-enough heuristic.
  KEYWORD=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]' | \
    grep -oE '[a-z]{5,}' | \
    grep -vE '^(still|would|could|should|might|about|which|where|there|these|those|their|other|might|every|while|first|doing|using|think|going|means|looks|means|needs|wants)$' | \
    sort | uniq -c | sort -rn | head -1 | awk '{print $2}')

  if [ -n "$KEYWORD" ]; then
    ARCH_FILE="$CACHE_DIR/arch-questions-${SESSION_ID}.txt"
    touch "$ARCH_FILE"
    echo "$KEYWORD" >> "$ARCH_FILE"
    COUNT=$(grep -cFx "$KEYWORD" "$ARCH_FILE")
    if [ "$COUNT" -eq 3 ]; then
      echo "💡 3 architecture questions about \"$KEYWORD\" this session. Consider writing docs/runbook-${KEYWORD}.md to capture the decision context." >&2
    fi
  fi
fi

# ----------------------------------------------------------------------------
# 3.4 — Narration telemetry (soft)
# Scan the last N assistant messages in the transcript for sentences that
# begin with "Let me", "Now let me", "I'll", "I'm going to", "I will now".
# Don't rewrite — just bump a counter file for weekly review.
# ----------------------------------------------------------------------------
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
  # Take last 20 assistant text messages, grep for the pattern.
  NARRATION_PATTERN='^(Let me|Now let me|I'"'"'ll |I am going to|I will now|Let'"'"'s)[[:space:]]'
  HITS=$(jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text' "$TRANSCRIPT_PATH" 2>/dev/null | \
    tail -80 | \
    grep -cE "$NARRATION_PATTERN" 2>/dev/null || echo 0)

  if [ "$HITS" -gt 0 ]; then
    COUNTER_FILE="$HOME/.claude/cache/narration-count.txt"
    CURRENT=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
    printf '%d\n' "$((CURRENT + HITS))" > "$COUNTER_FILE"
  fi
fi

exit 0
