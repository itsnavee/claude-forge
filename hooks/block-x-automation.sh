#!/bin/bash
# ============================================================================
# Hook: Block all X/Twitter automation
# Event: PreToolUse (Bash)
# Action: Exit 2 — blocks any attempt to fetch/scrape X/Twitter content.
#
# Why: Prior use of `twitter-cli` caused the user's X account to be suspended.
# No third-party fetcher (fxtwitter, nitter, vxtwitter, twstalker, etc.) is a
# safe substitute — all X automation is banned. GitHub and non-X web fetching
# remain allowed.
#
# If the user pastes an x.com URL, the model must ask them to paste the
# content instead of auto-fetching it.
# ============================================================================

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

[ -z "$COMMAND" ] && exit 0

# Unambiguous fetcher binaries — match anywhere in the command.
BINARY_PATTERN='\b(twitter-cli|fxtwitter|nitter|vxtwitter|twstalker|snscrape)\b'

# Ambiguous commands (`twitter`) — only match at command position: start of
# command, or after `;`, `&&`, `||`, `|`, `$(`, backtick. Matching anywhere
# would false-positive on any text containing the word "twitter" (commit
# messages, echo strings, file paths).
CMD_POSITION_PATTERN='(^|[;&|(`]|&&|\|\|)[[:space:]]*twitter[[:space:]]'

# Domain hits — only when the domain appears as a URL (preceded by scheme,
# whitespace, or quote and followed by /).
DOMAIN_PATTERN='(https?://|[[:space:]"'"'"'])(www\.)?(twitter\.com|x\.com|t\.co|fxtwitter\.com|nitter\.[a-z]+)/'

if echo "$COMMAND" | grep -qiE "$BINARY_PATTERN"; then
  echo "X/Twitter automation is BANNED — prior use suspended the X account." >&2
  echo "No third-party fetcher is an acceptable substitute." >&2
  echo "If you need content from a <item>, ask the user to paste it." >&2
  exit 2
fi

if echo "$COMMAND" | grep -qE "$CMD_POSITION_PATTERN"; then
  echo "X/Twitter automation is BANNED — \`twitter\` command detected at command position." >&2
  echo "Ask the user to paste <item> content instead." >&2
  exit 2
fi

if echo "$COMMAND" | grep -qiE "$DOMAIN_PATTERN"; then
  echo "X/Twitter automation is BANNED — command targets x.com / twitter.com / t.co." >&2
  echo "Ask the user to paste the content instead of auto-fetching." >&2
  exit 2
fi

exit 0
