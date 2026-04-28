#!/bin/bash
# ============================================================================
# Shared utility: Check if current repo is public
# Usage: source this file, then check IS_PUBLIC_REPO ("yes" or "no")
#        Also sets REPO_ROOT if in a git repo
# Method: prefer `gh repo view` (authoritative, authenticated, 5000/hr limit);
#         fall back to unauthenticated GitHub API (200=public, 404=private).
# Why not `git ls-remote`: cached HTTPS credentials (macOS keychain etc.) let
#         it succeed against private repos too — false-positive "public".
# ============================================================================

IS_PUBLIC_REPO="no"
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)

if [ -n "$REPO_ROOT" ]; then
  REMOTE_URL=$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null)
  if [ -n "$REMOTE_URL" ] && echo "$REMOTE_URL" | grep -q "github\.com"; then
    OWNER_REPO=$(echo "$REMOTE_URL" | sed -E 's|^.*github\.com[:/]||; s|\.git$||')
    if [ -n "$OWNER_REPO" ]; then
      VISIBILITY=""
      # Preferred: gh CLI (authenticated, definitive)
      if command -v gh >/dev/null 2>&1; then
        VISIBILITY=$(gh repo view "$OWNER_REPO" --json isPrivate -q .isPrivate 2>/dev/null)
        case "$VISIBILITY" in
          false) IS_PUBLIC_REPO="yes" ;;
          true)  IS_PUBLIC_REPO="no" ;;
          *)     VISIBILITY="" ;;
        esac
      fi
      # Fallback: unauthenticated GitHub API — 200=public, 404=private
      if [ -z "$VISIBILITY" ]; then
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://api.github.com/repos/$OWNER_REPO" 2>/dev/null)
        [ "$HTTP_CODE" = "200" ] && IS_PUBLIC_REPO="yes"
      fi
    fi
  fi
fi
